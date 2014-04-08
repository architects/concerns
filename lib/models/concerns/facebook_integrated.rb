# The FacebookIntegrated concern gets mixed into a user, and allows us to make
# calls to the facebook API on their behalf
module FacebookIntegrated
  extend ActiveSupport::Concern

  included do
    begin
      require 'rest-graph'
    rescue
      puts "You need to include the rest-graph gem in your project"
      raise
    end

    include PublicProfile if defined?(PublicProfile) && !ancestors.include?(PublicProfile)
  end

  # Override this method if the column you store the facebook access token
  # in on this user is different
  def facebook_access_token_value
    self.facebook_access_token
  end

  def facebook_graph
    @fb_graph ||= RestGraph.new(access_token: facebook_access_token_value)
  end

  def fbg
    facebook_graph
  end

  def list_friends_from_facebook
    User.find_from_facebook_ids(facebook_friend_facebook_ids)
  end

  def mutual_friends_list facebook_user_id
    Rails.cache.fetch("mutual_friends:#{ self.id }:#{ facebook_user_id }") do
      Array(@friend_objects ||= fbg.get("me/mutualfriends/#{ facebook_user_id }").fetch("data",[]) rescue nil).map do |obj|
        {
          id: obj["id"],
          name: obj["name"],
          thumbnail_url: "http://graph.facebook.com/#{ obj['id'] }/picture?type=large"
        }
      end
    end
  end

  def mutual_friends_count
    (mutual_friends_list rescue []).length
  end

  def facebook_friend_objects
    Array(@friend_objects ||= fbg.get("me/friends").fetch("data",[]) rescue nil)
  end

  def facebook_friend_facebook_ids
    facebook_friend_objects.map {|h| h["id"] }.compact
  end

  def apply_additional_facebook_metadata(data={})
    true
  end

  def update_with_facebook data, access_token, raw_data=nil
    self.email = data.email if respond_to?(:email=)
    self.username = data.username if respond_to?(:username=)

    self.first_name = data.first_name
    self.last_name = data.last_name
    self.full_name = data.name

    if new_record?
      self.password = self.password_confirmation = rand(16**16).to_s(36).slice(0,16)
      save!
    end

    self.facebook_user_id = data.id
    self.facebook_access_token = access_token

    self.update_profile_data  :gender => data.gender,
                              :full_name => data.name,
                              :facebook_user_id => data.id,
                              :first_name => data.first_name,
                              :last_name => data.last_name,
                              :display_name => data.name,
                              :location => data.location && data.location.name,
                              :facebook_location_id => data.location && data.location.id,
                              :locale => data.locale,
                              :timezone => data.timezone,
                              :verified_on_facebook => !!data.verified,
                              :birthday => data.birthday,
                              :thumbnail_url => "http://graph.facebook.com/#{ data.id }/picture?type=large"

    save!

    self
  end

  def facebook_api_data
    return @facebook_api_data if @facebook_api_data
    return nil unless self.facebook_access_token

    lookup = ApiRequest.lookup(self.facebook_access_token)
    lookup.success? && lookup.user_data
  end

  module ClassMethods
    def find_from_facebook_ids ids
      User.joins(:profile).where(facebook_user_id: Array(ids))
    end

    def find_or_create_for_facebook_access_token(access_token)
      existing_user = User.where(:facebook_access_token=>access_token).first

      return existing_user if existing_user

      api_lookup = ApiRequest.lookup(access_token)

      if api_lookup.success? && data = api_lookup.user_data

        case
        when data.email.to_s.length > 0
          find_by_method = :find_by_email
          value = data.email
        when data.email.to_s.length == 0 && data.username.present?
          find_by_method = :find_by_username
          value = data.username
        end

        user = (User.send(find_by_method, value) || User.new).update_with_facebook(data, access_token, api_lookup)
        user.instance_variable_set(:@facebook_api_data,data)
        user
      else
        user = User.new
        user.display_name = "Totscoop User"
        user.errors.add(:facebook_access_token, api_lookup.error_message)
        user
      end
    end
  end

  class ApiRequest
    attr_accessor :access_token, :request, :response

    FacebookAuthError = Class.new(Exception)

    def self.lookup access_token
      new(access_token)
    end

    def initialize(access_token, auto=true)
      @access_token = access_token

      if Rails.env.test?
        load_test_data!
      else
        run! if auto
      end
    end

    def success?
      error_message.nil?
    end

    def error_message
      @error_message
    end

    def user_data
      run! unless @ran
      @user_data ||= success? ? @response : {}
      @user_data
    end

    def load_test_data!
      @ran = true
      if access_token == "FAIL"
        @error_message = "Invalid oAuth token"
      else
        @user_data = Hashie::Mash.new(JSON.parse(IO.read(Rails.root.join("spec","support","fixtures","sample-facebook-response.json"))))
      end
    end

    def run!
      begin
        @request  = Typhoeus::Request.get("https://graph.facebook.com/me?access_token=#{ access_token }")
        @response = Hashie::Mash.new JSON.parse(request.response_body)

        if !@response.error.nil?
          @error_message = @response.error.message
        else
          @user_data = @response
        end
      rescue
        @error_message   = "Fatal Error"
        @error_message  += " #{ $! }" unless Rails.env.production?
      ensure
        @ran             = true
      end
    end
  end

end
