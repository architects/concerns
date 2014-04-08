module PublicProfile
  extend ActiveSupport::Concern

  included do
    include FacebookIntegrated
    has_one :profile
    before_create :build_default_profile
  end

  def build_default_profile
    build_profile
    true
  end

  def update_profile_attributes attrs
    profile.update_attributes(attrs)
  end
end
