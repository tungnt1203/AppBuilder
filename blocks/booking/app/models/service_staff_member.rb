class ServiceStaffMember < ApplicationRecord
  belongs_to :service
  belongs_to :staff_member

  validates :staff_member_id, uniqueness: { scope: :service_id }
end
