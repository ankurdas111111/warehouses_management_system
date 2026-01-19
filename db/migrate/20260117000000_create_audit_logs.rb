class CreateAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_logs do |t|
      t.string :action, null: false

      t.string :actor_type, null: false
      t.string :actor_identifier

      t.string :auditable_type
      t.bigint :auditable_id

      t.string :request_id
      t.string :request_method
      t.string :request_path
      t.string :ip

      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :audit_logs, :action
    add_index :audit_logs, :created_at
    add_index :audit_logs, %i[auditable_type auditable_id]
    add_index :audit_logs, :request_id
  end
end


