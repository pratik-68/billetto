namespace :voting do
  desc "Rebuild vote tallies and per-user votes by replaying the Voting events"
  task rebuild_read_models: :environment do
    Voting::RebuildReadModels.new.call
    puts "Rebuilt #{VoteTally.count} vote tallies and #{EventVote.count} user votes."
  end
end
