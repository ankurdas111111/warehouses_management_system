class AuditLog < ApplicationRecord
  ACTIONS = %w[
    admin.reports.orders
    admin.reports.inventory
    admin.wallets.credit
    admin.warehouses.create
    admin.warehouses.update
    admin.warehouses.destroy
    admin.skus.update
    admin.skus.destroy
    admin.inventory.create_sku
    admin.inventory.destroy
  ].freeze

  validates :action, presence: true
  validates :action, inclusion: { in: ACTIONS }, allow_nil: true

  def self.record!(action:, auditable: nil, metadata: {})
    create!(
      action: action,
      actor_type: "admin_basic_auth",
      actor_identifier: Current.admin_user.to_s,
      auditable_type: auditable&.class&.name,
      auditable_id: auditable&.id,
      request_id: Current.request_id,
      ip: Current.ip,
      request_path: Current.request_path,
      request_method: Current.request_method,
      metadata: metadata
    )
  end
end


