class AccountsController < ApplicationController
  layout "auth"

  def edit; end

  def update
    user = current_user
    unless user.authenticate(params[:current_password].to_s)
      flash.now[:alert] = "Your current password didn't match."
      return render :edit, status: :unprocessable_entity
    end
    if user.update(password: params[:password], password_confirmation: params[:password_confirmation])
      user.rotate_remember_token!   # signs out every other browser
      sign_in(user)
      redirect_to root_path, notice: "Password changed."
    else
      flash.now[:alert] = user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end
end
