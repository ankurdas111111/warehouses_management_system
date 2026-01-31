class Payment < ApplicationRecord
  belongs_to :order, optional: true
  belongs_to :payable, polymorphic: true, optional: true

  enum :status, {
    created: 0,
    authorized: 1,
    captured: 2,
    failed: 3
  }

  validates :provider, presence: true
  validates :provider_order_id, presence: true, uniqueness: { scope: :provider }
  validates :amount_paise, numericality: { only_integer: true, greater_than: 0 }

  validate :order_or_payable_present

  private

  def order_or_payable_present
    errors.add(:base, "payment must belong to an order or a payable") if order_id.blank? && payable_id.blank?
  end
end
