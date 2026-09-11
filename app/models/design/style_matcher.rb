require "net/http"
require "json"

# "Match style from photo": sends a reference image from the concept's library to
# Claude and asks for the closest choices among the 3D view's roof / exterior /
# roof-color presets, plus approximate hex colors. Returns a Result whose
# settings hash is safe to merge into Design::Concept#render_settings.
#
# Talks to the Messages API over plain HTTPS: the official `anthropic` gem
# (1.70) fails to load once ActiveSupport is present, so it is not used here.
class Design::StyleMatcher
  class MissingKey   < StandardError; end
  class Failed       < StandardError; end
  class Unauthorized < StandardError; end
  class RateLimited  < StandardError; end
  class ApiError     < StandardError; end

  ENDPOINT = URI("https://api.anthropic.com/v1/messages")
  MODEL    = "claude-opus-5"
  ROOFS       = %w[hip4 hip6 hip8 gable4 gable6 gable8 flat none].freeze
  EXTERIORS   = %w[stucco white gray siding brick].freeze
  ROOF_COLORS = %w[asphalt brown tile metal].freeze
  HEX = /\A#[0-9a-f]{6}\z/i

  Result = Struct.new(:settings, :notes, keyword_init: true)

  SYSTEM = "You help match a simple 3D house model to a reference image (a photo, rendering, or elevation drawing). Answer with a single JSON object and nothing else.".freeze
  PROMPT = <<~TXT.freeze
    Pick the closest option in each list so the 3D model matches this house's style.

    roof: hip4, hip6, hip8, gable4, gable6, gable8 (the number is the pitch in inches of rise per foot), flat, none
    exterior: stucco (smooth stucco, cream), white (white walls), gray (warm gray), siding (horizontal wood or lap siding), brick
    roofColor: asphalt (gray shingle), brown (brown shingle), tile (terracotta clay tile), metal (standing-seam metal, blue-gray)

    Also estimate exteriorHex (the main wall color as #rrggbb) and roofHex (the roof color as #rrggbb).
    Add "notes": one short sentence describing the style and anything these options cannot capture (trim color, stone accents, dormers, porch).

    Respond with only: {"roof": "...", "exterior": "...", "roofColor": "...", "exteriorHex": "#......", "roofHex": "#......", "notes": "..."}
  TXT

  def self.call(image)
    new(image).call
  end

  def initialize(image)
    @image = image
  end

  def call
    key = ENV["ANTHROPIC_API_KEY"].presence or raise MissingKey, "ANTHROPIC_API_KEY is not set on the server."
    data, mime = image_bytes
    body = {
      model: MODEL, max_tokens: 1000, system: SYSTEM,
      messages: [{ role: "user", content: [
        { type: "image", source: { type: "base64", media_type: mime, data: Base64.strict_encode64(data) } },
        { type: "text", text: PROMPT }
      ] }]
    }
    response = Net::HTTP.start(ENDPOINT.host, ENDPOINT.port, use_ssl: true, open_timeout: 15, read_timeout: 120) do |http|
      http.post(ENDPOINT.path, body.to_json, "content-type" => "application/json", "x-api-key" => key, "anthropic-version" => "2023-06-01")
    end
    handle(response)
  rescue SocketError, Timeout::Error, Errno::ECONNRESET, OpenSSL::SSL::SSLError => e
    raise ApiError, "could not reach the Anthropic API (#{e.class.name.demodulize})"
  end

  private

  def handle(response)
    json = JSON.parse(response.body) rescue {}
    case response.code.to_i
    when 200
      raise Failed, "The model declined to analyze this image." if json["stop_reason"] == "refusal"
      parse(Array(json["content"]).select { |b| b["type"] == "text" }.map { |b| b["text"] }.join)
    when 401 then raise Unauthorized, "The Anthropic API key was rejected."
    when 429 then raise RateLimited, "Rate limited by the Anthropic API. Try again in a minute."
    else raise ApiError, json.dig("error", "message").to_s.presence || "HTTP #{response.code}"
    end
  end

  # A 1600px JPEG keeps the request small; fall back to the original file.
  def image_bytes
    variant = @image.file.variant(resize_to_limit: [1600, 1600], format: :jpeg, saver: { quality: 85 }).processed
    [variant.download, "image/jpeg"]
  rescue StandardError
    blob = @image.file.blob
    raise Failed, "This image is too large to analyze (over 5 MB)." if blob.byte_size > 5.megabytes
    [@image.file.download, blob.content_type]
  end

  def parse(text)
    json = text[/\{.*\}/m] or raise Failed, "Unexpected reply from the model."
    raw  = JSON.parse(json)
    settings = {}
    settings["roof"]        = raw["roof"]      if ROOFS.include?(raw["roof"])
    settings["exterior"]    = raw["exterior"]  if EXTERIORS.include?(raw["exterior"])
    settings["roofColor"]   = raw["roofColor"] if ROOF_COLORS.include?(raw["roofColor"])
    settings["exteriorHex"] = raw["exteriorHex"].downcase if raw["exteriorHex"].to_s.match?(HEX)
    settings["roofHex"]     = raw["roofHex"].downcase     if raw["roofHex"].to_s.match?(HEX)
    raise Failed, "The model could not read a house style from this image." if settings.empty?
    Result.new(settings: settings, notes: raw["notes"].to_s.strip.truncate(220))
  rescue JSON::ParserError
    raise Failed, "Unexpected reply from the model."
  end
end
