if Rails.env.test?
  # GitHub CI does not run a Redis service. In test, use Sidekiq's in-memory
  # testing mode so enqueues don't require Redis.
  require "sidekiq/testing"
  Sidekiq::Testing.fake!
else
  Sidekiq.configure_server do |config|
    config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6380/0") }

    # Load periodic jobs from config/sidekiq.yml (requires sidekiq-cron gem)
    config.on(:startup) do
      next if ENV.fetch("SIDEKIQ_CRON_ENABLED", "1") == "0"

      schedule_file = Rails.root.join("config/sidekiq.yml")
      next unless File.exist?(schedule_file)

      require "sidekiq/cron/job"
      raw = ERB.new(File.read(schedule_file)).result
      # Sidekiq's config YAML commonly uses Symbol keys (e.g. :concurrency:, :schedule:).
      # Psych.safe_load rejects Symbol by default, so we load this trusted local file normally.
      cfg = YAML.load(raw, aliases: true) || {}
      schedule = cfg[:schedule] || cfg["schedule"] || {}
      Sidekiq::Cron::Job.load_from_hash(schedule)
    end
  end

  Sidekiq.configure_client do |config|
    config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6380/0") }
  end
end
