# frozen_string_literal: true

# Handling a new user registration through the sign-up modal
class RegistrationsController < Devise::RegistrationsController
  def destroy
    unless resource.destroy
      respond_to do |format|
        format.json { render json: resource.errors.full_messages, status: :unprocessable_entity }
        format.html do
          redirect_to root_path(anchor: '!/dashboard/settings'), alert: resource.errors.full_messages.to_sentence, status: :see_other
        end
      end
      return
    end

    Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name)
    set_flash_message! :notice, :destroyed
    yield resource if block_given?
    respond_with_navigational(resource) do
      redirect_to after_sign_out_path_for(resource_name), status: Devise.responder.redirect_status
    end
  end

  # POST /users.json
  def create
    # Is public registration allowed?
    unless Setting.get('public_registrations')
      render json: { errors: { signup: [t('errors.messages.registration_disabled')] } }, status: :forbidden and return
    end

    # first check the recaptcha
    check = RecaptchaService.verify(params[:user][:recaptcha])
    render json: check['error-codes'], status: :unprocessable_entity and return unless check['success']

    # then create the user
    build_resource(sign_up_params)

    resource_saved = resource.save
    yield resource if block_given?
    if resource_saved
      if resource.active_for_authentication?
        set_flash_message :notice, :signed_up if is_flashing_format?

        sign_up(resource_name, resource) unless Setting.get('confirmation_required')
        respond_with resource, location: after_sign_up_path_for(resource)
      else
        set_flash_message :notice, :"signed_up_but_#{resource.inactive_message}" if is_flashing_format?
        expire_data_after_sign_in!
        respond_with resource, location: after_inactive_sign_up_path_for(resource)
      end
    else
      clean_up_passwords resource
      respond_with resource
    end
  end
end
