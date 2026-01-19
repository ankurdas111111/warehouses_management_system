class Current < ActiveSupport::CurrentAttributes
  attribute :user
  attribute :admin_user
  attribute :request_id
  attribute :request_path
  attribute :request_method
  attribute :ip
end


