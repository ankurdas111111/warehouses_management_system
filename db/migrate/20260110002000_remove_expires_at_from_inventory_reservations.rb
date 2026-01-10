class RemoveExpiresAtFromInventoryReservations < ActiveRecord::Migration[8.1]
  def change
    remove_column :inventory_reservations, :expires_at, :datetime
  end
end


