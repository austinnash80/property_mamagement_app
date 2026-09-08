module DesignHelper
  def dc_date(time, format = "%b %-d, %Y")
    time.present? ? time.strftime(format) : "—"
  end

  def dc_status_badge(status)
    css = { "idea" => "secondary", "in_progress" => "warning text-dark", "complete" => "success" }[status.to_s] || "light text-dark"
    content_tag(:span, status.to_s.humanize, class: "badge bg-#{css}")
  end

  # "floor_plan" -> "Floor plan"
  def dc_label(value)
    value.to_s.humanize
  end

  def dc_options(values)
    values.map { |v| [dc_label(v), v] }
  end

  def dc_tags(list)
    safe_join(list.map { |t| content_tag(:span, t, class: "badge bg-light text-dark border me-1") })
  end

  # Renders a variant when ImageMagick can process the file, otherwise the original.
  def dc_image_tag(image, variant = :thumb, **opts)
    return unless image.file.attached?
    if image.file.variable?
      image_tag(image.public_send(variant), **opts)
    else
      image_tag(image.file, **opts)
    end
  rescue StandardError
    image_tag(image.file, **opts)
  end

  # Source field: link it when it is a URL, otherwise show the text.
  def dc_source(source)
    return if source.blank?
    if source =~ %r{\Ahttps?://}i
      link_to source.sub(%r{\Ahttps?://(www\.)?}i, "").truncate(50), source, target: "_blank", rel: "noopener"
    else
      source
    end
  end
end
