class Download < ApplicationRecord
  STATUS_INITIAL    = "initial"
  STATUS_QUEUED     = "queued"
  STATUS_STARTED    = "started"
  STATUS_FINISHED   = "finished"
  STATUS_ERROR      = "error"
  STATUS_CANCELLED  = "cancelled"
  VALID_STATUSES    = [STATUS_INITIAL, STATUS_QUEUED, STATUS_STARTED, STATUS_FINISHED, STATUS_ERROR, STATUS_CANCELLED]

  belongs_to :user

  validates_presence_of :url
  validates_format_of :url, with: URI::regexp(%w(http https))
  validates_uniqueness_of :url, scope: :user_id
  validates_inclusion_of :status, in: VALID_STATUSES

  # scope :last_n,    lambda { |n| order(id: :desc).limit(n) }
  # scope :last_10,   -> { order(id: :desc).limit(10) }
  # scope :initial,   -> { where(status: STATUS_INITIAL) }
  # scope :queued,    -> { where(status: STATUS_QUEUED) }
  # scope :started,   -> { where(status: STATUS_STARTED) }
  # scope :finished,  -> { where(status: STATUS_FINISHED) }
  # scope :error,     -> { where(status: STATUS_ERROR) }
  # scope :cancelled, -> { where(status: STATUS_CANCELLED) }

  # def self.latest
  #   [initial.last_n(5), queued.last_n(5), started.last_n(5), finished.last_n(5), error.last_n(5)].compact.flatten
  # end

  def queue!    
    return if queued? || started?
    Resque.enqueue(DownloadJob, id)
    queued!
  end

  def run!    
    begin
      return if cancelled?
      started!
      Rails.env.development? ? sleep(rand(10)) : system(command)
      finished!
    rescue => e
      error!(e.message)
    end    
  end

  def queued!
    update(status: STATUS_QUEUED, queued_at: Time.zone.now, started_at: nil, finished_at: nil, error: nil)
  end
  def queued?
    status == STATUS_QUEUED
  end
  def started!    
    update(status: STATUS_STARTED, started_at: Time.zone.now, finished_at: nil, error: nil)
  end
  def started?
    status == STATUS_STARTED
  end
  def finished!
    update(status: STATUS_FINISHED, finished_at: Time.zone.now)
  end
  def error!(message)
    update(status: STATUS_ERROR, finished_at: Time.zone.now, error: message)
  end
  def cancelled!
    update(status: STATUS_CANCELLED, cancelled_at: Time.zone.now)
  end
  def cancelled?
    status == STATUS_CANCELLED
  end

  def to_json
    {}.tap do |ret|
      keys = attributes.keys
      keys.delete("user_id")
      keys.each do |key|
        value = send(key)
        ret[key] = value.is_a?(ActiveSupport::TimeWithZone) ? value.iso8601 : value
      end
      ret[:user] = user.to_json
    end
  end

private

  def prep_output_path
    dir = ENV['OUTPUT_PATH']
    FileUtils.mkdir_p(dir) unless File.exists?(dir)
  end

  def command
    cmd = ["get_iplayer"]
    cmd << "--proxy #{ENV['PROXY']}" if ENV['PROXY']
    cmd << "--url \"#{url}\" --force --modes best"
    if ENV['OUTPUT_PATH']
      prep_output_path
      cmd << "--output \"#{ENV['OUTPUT_PATH']}\"" 
    end
    cmd.join(" ")
  end
end
