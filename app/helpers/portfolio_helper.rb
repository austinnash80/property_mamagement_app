module PortfolioHelper
  def money(amount)
    return "—" if amount.blank?
    number_to_currency(amount, precision: 2)
  end

  def pdate(date, format = "%b %-d, %Y")
    date.present? ? date.strftime(format) : "—"
  end

  def status_badge(status)
    css = { "completed" => "success", "in_progress" => "warning text-dark", "planned" => "secondary",
            "owned" => "primary", "sold" => "secondary" }[status.to_s] || "light text-dark"
    content_tag(:span, status.to_s.humanize, class: "badge bg-#{css}")
  end

  def stage_badge(stage)
    css = { "before" => "danger", "during" => "warning text-dark", "after" => "success" }[stage.to_s] || "secondary"
    content_tag(:span, stage.to_s.capitalize, class: "badge bg-#{css}")
  end

  def file_icon(blob)
    blob.image? ? "🖼" : (blob.content_type.to_s.include?("pdf") ? "📄" : "📎")
  end

  def safe_image(photo, variant = :thumb, **opts)
    return unless photo.image.attached?
    if photo.image.variable?
      image_tag(photo.public_send(variant), **opts)
    else
      image_tag(photo.image, **opts)
    end
  rescue StandardError
    image_tag(photo.image, **opts)
  end
end
