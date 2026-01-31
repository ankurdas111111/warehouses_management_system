module UiHelper
  def badge_class_for_order_status(status)
    case status.to_s
    when "fulfilled"
      "badge badge--success"
    when "partially_fulfilled"
      "badge badge--warning"
    when "reserved"
      "badge badge--info"
    when "cancelled"
      "badge badge--danger"
    else
      "badge badge--neutral"
    end
  end

  def badge_class_for_payment_status(status)
    case status.to_s
    when "paid"
      "badge badge--success"
    when "payment_failed"
      "badge badge--danger"
    when "refunded"
      "badge badge--info"
    else
      "badge badge--neutral"
    end
  end

  def badge_class_for_fulfillment_status(status)
    case status.to_s
    when "completed"
      "badge badge--success"
    when "failed"
      "badge badge--danger"
    else
      "badge badge--neutral"
    end
  end

  def badge_class_for_reservation_status(status)
    case status.to_s
    when "fulfilled"
      "badge badge--success"
    when "expired"
      "badge badge--danger"
    else
      "badge badge--neutral"
    end
  end
end
