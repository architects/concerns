# The TokenAuthenticatable mixin provides the ability to authenticate users who are making
# API requests through the use of request headers or query parameters
module TokenAuthenticatable
  module ControllerMixin
    extend ActiveSupport::Concern

    included do
      prepend_before_filter :get_auth_token
    end

    def authenticate_user_from_token!
      if auth_token = params[:auth_token]
        id,authentication_token = auth_token.split(':')

        user = id && authentication_token && User.find(id)

        if user && Devise.secure_compare(user.persisted_authentication_token, authentication_token)
          sign_in(user, store: false)
        end
      end
    end

    def get_auth_token
      token = request.headers['X-AUTH-TOKEN'] || request.headers['HTTP_X_AUTH_TOKEN']

      if auth_token = params[:auth_token].blank? && token
        params[:auth_token] = auth_token
      end
    end

    module ClassMethods
      def requires_authentication options={}
        before_filter(:authenticate_user_from_token!, options)
        before_filter(:authenticate_user!, options)
      end
    end
  end

  module ModelMixin
    extend ActiveSupport::Concern

    included do
      after_create :reset_authentication_token!
    end

    def after_password_reset
      reset_authentication_token!
    end

    def persisted_authentication_token
      read_attribute(:authentication_token)
    end

    def authentication_token
      "#{ self.id }:#{ persisted_authentication_token }"
    end

    def auth_token
      authentication_token
    end

    def reset_authentication_token!
      update_attribute(:authentication_token, Devise.friendly_token)
    end

  end
end
