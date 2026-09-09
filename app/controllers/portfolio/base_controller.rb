require "csv"

class Portfolio::BaseController < ApplicationController
  layout "portfolio"

  # License reviewers may browse the portfolio without the password: read-only
  # pages of properties, projects and vendors. The inbox, CSV exports and every
  # form or write action stay locked.
  PUBLIC_CONTROLLERS = %w[portfolio/properties portfolio/projects portfolio/vendors].freeze

  private

  def public_request?
    request.get? && PUBLIC_CONTROLLERS.include?(controller_path) && %w[index show].include?(action_name)
  end

  def send_csv(name, headers, rows)
    csv = CSV.generate(headers: true) do |out|
      out << headers
      rows.each { |r| out << r }
    end
    send_data csv, filename: "portfolio-#{name}-#{Time.zone.now.strftime('%Y-%m-%d_%H%M')}.csv", type: "text/csv"
  end
end
