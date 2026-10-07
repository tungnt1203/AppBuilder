# The shop's policies and contact details (Settings → Policies), shown at /policies/:id and
# /contact. Empty policies start from a template the owner reads and adjusts before saving.
class Admin::PoliciesController < Admin::BaseController
  before_action :require_administrator
  before_action :set_store

  def edit
  end

  def update
    if @store.update(policy_params)
      redirect_to edit_admin_policies_path, notice: t(".notice")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_store
      @store = Store.current
    end

    def policy_params
      params.expect(store: [ :contact_email, :contact_phone, :business_address, *Store::POLICIES.values ])
    end
end
