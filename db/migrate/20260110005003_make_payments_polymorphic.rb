class MakePaymentsPolymorphic < ActiveRecord::Migration[8.1]
  def change
    add_reference :payments, :payable, polymorphic: true, null: true
    change_column_null :payments, :order_id, true
  end
end
