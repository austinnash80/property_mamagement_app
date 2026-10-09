# Family logins. There is no email delivery configured in this app, so there are
# no invites or reset links: the owner creates each account with a password and
# passes it along. Everyone can then change their own password at /account.
class Family::MembersController < Family::BaseController
  before_action :require_owner
  before_action :set_member, only: %i[edit update destroy]

  def index
    @members = User.by_name
    @member  = User.new(role: "family")
  end

  def new
    @member = User.new(role: "family")
  end

  def edit; end

  def create
    @member = User.new(member_params)
    if @member.save
      redirect_to family_members_path, notice: "#{@member.display_name} can now sign in."
    else
      @members = User.by_name
      render :index, status: :unprocessable_entity
    end
  end

  # A blank password field leaves the existing password alone.
  def update
    attrs = member_params
    attrs = attrs.except(:password) if attrs[:password].blank?
    attrs = attrs.except(:role)     if @member == current_user   # don't lock yourself out
    if @member.update(attrs)
      redirect_to family_members_path, notice: "Account updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @member == current_user
      redirect_to family_members_path, alert: "You can't delete your own account."
    else
      @member.destroy
      redirect_to family_members_path, notice: "Account removed."
    end
  end

  private

  def require_owner
    redirect_to family_root_path, alert: "Only the account owner can manage family logins." unless current_user&.owner?
  end

  def set_member
    @member = User.find(params[:id])
  end

  def member_params
    params.require(:user).permit(:name, :email, :password, :role)
  end
end
