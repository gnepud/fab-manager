# frozen_string_literal: true

# Devise controller used for the "forgotten password" feature and to check the current's user password
class PasswordsController < Devise::PasswordsController
  # PUT /users/password.json
  def update
    super do |user|
      if request.format.json? && user.errors.any?
        return render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end

  # POST /users/password.json
  def create
    self.resource = resource_class.send_reset_password_instructions(resource_params)
    yield resource if block_given?

    respond_with({}, location: after_sending_reset_password_instructions_path_for(resource_name)) if successfully_sent?(resource)
  end

  # POST /password/verify
  def verify
    current_user.valid_password?(params[:password]) ? head(:ok) : head(:not_found)
  end
end
