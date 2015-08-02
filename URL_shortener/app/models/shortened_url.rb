# == Schema Information
#
# Table name: shortened_urls
#
#  id           :integer          not null, primary key
#  long_url     :string
#  short_url    :string
#  submitter_id :integer
#  created_at   :datetime
#  updated_at   :datetime
#

class ShortenedUrl < ActiveRecord::Base
  validate :not_too_many_urls
  validates :short_url, presence: true, uniqueness: true
  validates :submitter_id, presence: true
  validates :long_url, length: { maximum: 1024 }

  belongs_to(
    :submitter,
    class_name: "User",
    foreign_key: :submitter_id,
    primary_key: :id
  )

  has_many(
    :visits,
    class_name: "Visit",
    foreign_key: :shortened_url_id,
    primary_key: :id
  )

  has_many(
    :visitors,
    -> { distinct },
    through: :visits,
    source: :user
  )

  has_many(
    :taggings,
    class_name: "Tagging",
    foreign_key: :shortened_url_id,
    primary_key: :id
  )


  def self.random_code
    random_code = SecureRandom::urlsafe_base64

    while ShortenedUrl.exists?(short_url: random_code)
      random_code = SecureRandom::urlsafe_base64
    end

    random_code
  end

  def self.create_for_user_and_long_url!(user, long_url)
    random_code = ShortenedUrl.random_code
    user_id = user.id
    ShortenedUrl.create!(short_url: random_code, long_url: long_url, submitter_id: user_id)
  end

  def self.prune(n)
    recently_visited_urls = []
    ShortenedUrl.all.each do |url_object|
      if url_object.visits.where(created_at: n.minutes.ago..Time.now).count > 0
        recently_visited_urls << url_object
      end
    end

    ShortenedUrl.all.each do |url_object|
      url_id = url_object.id

      unless recently_visited_urls.include?(url_object)
        ShortenedUrl.find(url_id).destroy
      end
    end
  end

  def num_clicks
    self
      .visits
      .count
  end

  def num_uniques
    self.visitors.count

    # self  #ShortenedUrl.find(self.id) replaced by self
    #   .visits
    #   .select(:user_id)
    #   .distinct
    #   .count
  end

  def num_recent_uniques
    self
      .visits
      .where(created_at: 30.minutes.ago..Time.now)
      .current_visits.select(:user_id)
      .distinct
      .count
  end

    private
    def not_too_many_urls
      recent_submissions = ShortenedUrl
                          .where(submitter_id: submitter_id, created_at: 1.minute.ago..Time.now)
                          .count
      premium_user = User.find(submitter_id).premium
      if recent_submissions >= 5 && !premium_user
        errors[:recent_submissions] << "You added too many urls"
      end
    end
end
