# The people who run a shop, for its owners: add someone by email (an account is made for them
# when they don't have one, with an invitation to choose their password), change what they can
# do, or take them off. A shop always keeps an owner.
class ShopAdmin::MembershipsController < ShopAdmin::BaseController
  before_action :require_owner
  before_action :set_membership, only: %i[ update destroy ]

  def index
    @memberships = current_shop.memberships.includes(:user).order(:created_at)
  end

  def new
    @membership = current_shop.memberships.build(role: "staff")
  end

  def create
    @membership = current_shop.memberships.build(role: params.dig(:membership, :role))
    email_address = params.dig(:membership, :email_address).to_s.strip.downcase
    user = User.find_by(email_address:)
    new_account = user.nil?
    user ||= User.invite(name: params.dig(:membership, :name).to_s.presence || email_address.split("@").first, email_address:)
    @membership.user = user

    if user.persisted? && @membership.save
      InvitationsMailer.invite(user, current_shop).deliver_later if new_account
      redirect_to shop_admin_memberships_path, notice: t(".notice#{"_invited" if new_account}", name: user.name)
    else
      user.errors.each { |error| @membership.errors.add(:base, error.full_message) } unless user.persisted?
      render :new, status: :unprocessable_entity
    end
  end

  def update
    role = params.expect(membership: [ :role ])[:role]
    if last_owner?(@membership) && role != "owner"
      redirect_to shop_admin_memberships_path, alert: t(".last_owner"), status: :see_other
    else
      @membership.update!(role:)
      redirect_to shop_admin_memberships_path, notice: t(".notice", name: @membership.user.name), status: :see_other
    end
  end

  def destroy
    if last_owner?(@membership)
      redirect_to shop_admin_memberships_path, alert: t("shop_admin.memberships.update.last_owner"), status: :see_other
    else
      @membership.destroy!
      redirect_to shop_admin_memberships_path, notice: t(".notice", name: @membership.user.name), status: :see_other
    end
  end

  private
    def require_owner
      redirect_to shop_admin_root_path, alert: t("shop_admin.memberships.only_owners") unless current_membership.owner?
    end

    def set_membership
      @membership = current_shop.memberships.find(params[:id])
    end

    def last_owner?(membership)
      membership.role == "owner" && current_shop.memberships.where(role: "owner").count == 1
    end
end
