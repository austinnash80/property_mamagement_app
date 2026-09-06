require "csv"

class Portfolio::BaseController < ApplicationController
  layout "portfolio"

  private

  def send_csv(name, headers, rows)
    csv = CSV.generate(headers: true) do |out|
      out << headers
      rows.each { |r| out << r }
    end
    send_data csv, filename: "portfolio-#{name}-#{Time.zone.now.strftime('%Y-%m-%d_%H%M')}.csv", type: "text/csv"
  end
end
