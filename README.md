# Billetto Events

A Rails 8.1 app that:
- imports public events from the Billetto API into PostgreSQL;
- lists the upcoming ones;
- lets users who are signed in with Clerk upvote or downvote them.

Votes are event-sourced with Rails Event Store. The UI is deliberately minimal: the focus of this exercise is backend architecture.

## Setup

**Prerequisites:**
- Ruby 3.2.2 (see `.ruby-version`).
- PostgreSQL 14+ running locally. The app connects over the default socket as your OS user; see `config/database.yml`.
- Google Chrome, for the browser specs only.

**Steps:**

```sh
cp .env.example .env     # then fill in the keys below
bin/setup --skip-server  # bundle install, create + migrate the databases
bin/rails billetto:import          # import all public events (MAX_PAGES=2 for a quick sample)
bin/dev                  # http://localhost:3000
```

| Variable | Where to get it |
|---|---|
| `BILLETTO_API_KEYPAIR` | Billetto organiser account → *Switch to Organiser* → *Integrate* → *Developers* → generate a key pair. Value is `key:secret`. |
| `CLERK_PUBLISHABLE_KEY`, `CLERK_SECRET_KEY` | dashboard.clerk.com → your application → *Configure* → *API keys* (development instance). |

**Useful extras:**
- `bin/rails voting:rebuild_read_models` rebuilds vote counts from the event store.
- http://localhost:3000/res opens the Rails Event Store browser (development only).
- `ImportEventsJob` wraps the import, for a scheduler or cron.

## Tests

```sh
bundle exec rspec                                        # no network; includes headless-Chrome specs
CLERK_E2E=1 bundle exec rspec --tag clerk                # real Clerk sign-up → vote → sign-out → sign-in
```

| Area | Spec |
|---|---|
| Event model validations and DB constraints | `spec/models/event_spec.rb` |
| API client: pagination, retries, errors | `spec/services/billetto/client_spec.rb` (WebMock) |
| Payload mapping | `spec/services/billetto/event_payload_spec.rb` (real API fixture) |
| Import: idempotency, invalid records | `spec/services/events/import_spec.rb` |
| Voting rules (aggregate) | `spec/domain/voting/ballot_spec.rb` |
| Events stored in RES (streams, data, metadata, conflict retry) | `spec/domain/voting/ballot_command_handler_spec.rb` |
| Vote counts and rebuild from the event store | `spec/read_models/voting/projections_spec.rb` |
| Guests cannot vote; signed-in voting over HTTP | `spec/requests/votes_spec.rb` |
| Browser voting flow | `spec/system/voting_spec.rb` (Cuprite) |
| Browser authentication flow against real Clerk | `spec/system/clerk_authentication_spec.rb` (opt-in) |

**How auth is tested without Clerk:** in the default suite the Clerk Rack middleware is replaced by a test-only `FakeClerkSession` (`spec/support/clerk.rb`). It builds the same `request.env["clerk"]` object the real middleware builds from a verified token, so application code is exercised unchanged.

**How the real-Clerk spec works:**
- Clerk *test mode* makes `+clerk_test` email addresses accept the code `424242`, so no real email is sent.
- Clerk's bot protection would block the automated browser. The spec gets a Clerk *Testing Token* from the Backend API and adds it to the browser's Frontend API requests, which is what `@clerk/testing` does for Playwright.

## Architecture

```
Billetto API ──► Billetto::Client ──► Billetto::EventPayload ──► Events::Import ──► events (upsert)
                 (HTTP, retries,      (maps the external           (validates with Event,
                  pagination)          schema)                      one upsert per page)

Browser ──► VotesController ──► CommandBus ──► Voting::BallotCommandHandler ──► Voting::Ballot (aggregate)
            (Clerk user id)     UpvoteEvent                                          │ EventUpvoted /
                                DownvoteEvent                                        │ EventDownvoted /
                                WithdrawVote                                         ▼ VoteWithdrawn
                                                              Rails Event Store (event_store_events)
                                                                     │ sync subscribers, same transaction
                                                                     ├─► TallyProjection     ─► vote_tallies
                                                                     └─► EventVoteProjection ─► event_votes
```

| Directory | Contents |
|---|---|
| `app/services/billetto/`, `app/services/events/` | Ingestion. |
| `app/domain/voting/` | Voting bounded context: domain events, commands, the aggregate, the command handler, wiring. |
| `app/read_models/voting/` | Projections, the vote summary query, and the read-model rebuild. |
| `app/controllers/concerns/authentication.rb` | Clerk integration. |

## Rails Event Store setup

1. **Gems:** `rails_event_store`, `aggregate_root` and `arkency-command_bus`, all 3.0.x. RES 3.1+ requires Ruby 3.3.
2. **Schema:** created with `bin/rails g ruby_event_store:active_record:migration --data-type=jsonb`. This creates the `event_store_events` and `event_store_events_in_streams` tables.
3. **Client** (`config/initializers/event_store.rb`):
   - `RailsEventStore::JSONClient` serialises events to `jsonb` and keeps symbol keys when reading them back.
   - The Railtie adds `RailsEventStore::Middleware`, so every event carries `request_id` and `remote_ip` in its metadata.
   - `Voting::Configuration` registers the command handler on an `Arkency::CommandBus` and subscribes the projections.
4. **Events:**

   | Event | `data` |
   |---|---|
   | `Voting::EventUpvoted` | `{ event_id, user_id, previous_vote }` |
   | `Voting::EventDownvoted` | `{ event_id, user_id, previous_vote }` |
   | `Voting::VoteWithdrawn` | `{ event_id, user_id, withdrawn_vote }` |

   `user_id` is the Clerk user id. It is stored in `data` and also in `metadata`, for traceability.
5. **Streams:** `Voting::Ballot$<event_id>$<clerk_user_id>` holds one stream per user per event.
6. **Read models:**
   - `vote_tallies` holds the counts shown on the list page.
   - `event_votes` holds the signed-in user's current vote.
   - Both are disposable and can be rebuilt with `voting:rebuild_read_models`.

## Design choices

- **The aggregate is one user's ballot on one event.** "One vote per user per event" is an invariant about a single (user, event) pair, so that pair is the consistency boundary.
  - Loading the aggregate replays only a handful of events.
  - Two users voting on the same event never conflict.
  - A double click on the same ballot fails RES's optimistic concurrency check, and the handler retries it once against fresh state.
  - A per-event aggregate would serialise every voter on a popular event and grow without bound.
- **Commands are idempotent.** Repeating your current vote, or withdrawing when you have no vote, records nothing. That matches `PUT` and `DELETE /events/:id/vote`, so retries and double submits are safe.
- **Events say what they replace.** `previous_vote` and `withdrawn_vote` let projections update counters atomically (`upvotes = upvotes + 1`) without reading other state. Rebuilding from the event store produces identical tables, and a spec checks this.
- **Projections are synchronous, in the same transaction.** The counts can never disagree with the event store, and the user sees their vote immediately. At higher volume they could become async RES handlers (ActiveJob) with eventual consistency, and nothing else would need to change.
- **Billetto events are not event-sourced.** They are a copy of an external system's data, so a plain table updated by upsert is the right tool. Only the votes, which are this app's own behaviour, go through the event store.
- **Ingestion:**
  - The client retries timeouts, 429s and 5xx responses with exponential backoff. Anything else becomes a typed `Billetto::Client::Error`.
  - It follows the API's cursor (`next_url`) only on the API host, so the keypair is never sent anywhere else.
  - Each record is validated with the same `Event` validations used everywhere else. Invalid records are logged and skipped, and one bad record never fails a run.
  - Each page is written with one `upsert_all` on `external_id`, so re-running the import is idempotent and picks up upstream changes.
  - The unique index, rather than a uniqueness validation, guarantees one row per Billetto event. A uniqueness validation would cost a query per row and still be open to races.
- **Clerk:**
  - The official `clerk-sdk-ruby` Rack middleware verifies the session token from the cookie or the `Authorization` header, including Clerk's development-instance handshake.
  - The app keeps no user table: the Clerk user id is the identity stored with votes.
  - The frontend uses ClerkJS's prebuilt `<SignIn/>` and `<SignUp/>` components, loaded from the instance's own domain, with no JS build step.
- **Lean dependencies.** Only the Rails frameworks the app uses are loaded. There is no mailer, Action Cable, Active Storage or asset pipeline.

## Assumptions

- **Undated events are skipped.** Some Billetto events (`kind: "regular"`) have no `startdate`, so the listing can't show a date for them. They are skipped and logged, and the import reports them as `skipped`.
- **"Upcoming" means not yet finished,** judged by `ends_at` (or `starts_at` when there is no end time).
- **Times are stored and shown in UTC,** labelled as such, exactly as the API provides them. Showing each event in its own local time zone is listed under next steps.
- **Switching counts as one vote.** Voting the other way replaces your vote rather than adding a second one, and a vote can be withdrawn.

## Possible next steps

- Showing each event in its local time zone (from its `country_code`) instead of UTC.
- Async projections, plus a stream per Billetto event (RES `link`) for a per-event audit view.
- Scheduling `ImportEventsJob` with a persistent queue (Solid Queue), and removing events that disappear upstream.
- Clerk webhooks to keep a local user profile, for example to show voter names.
- Versioning event schemas (upcasting) once the voting events change shape.
