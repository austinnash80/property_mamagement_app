require "test_helper"
require "minitest/mock"

# The Family section holds codes, passwords and health details. These pin down
# that the private part of an entry stays off lock screens and out of the logs.
class Family::PrivacyTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "family-privacy@example.com", name: "Austin", password: "test-pass", role: "family")
    User.create!(email: "family-privacy-2@example.com", name: "Christina", password: "test-pass", role: "family")
    post login_path, params: { email: @user.email, password: "test-pass" }
  end

  {
    family_references_path:     [:family_reference,   { category: "Wifi & codes" }],
    family_andie_entries_path:  [:family_andie_entry, { section: "Other" }],
    family_rae_entries_path:    [:family_rae_entry,   { section: "Other" }]
  }.each do |path, (key, extra)|
    test "#{key} notifications name the entry but not its value" do
      pushed = []
      # Capture what would be pushed instead of sending it.
      Family::Notifier.stub(:notify_others, ->(_actor, **message) { pushed << message; 0 }) do
        post public_send(path), params: { notify: 1, key => { title: "Garage code", value: "4821" }.merge(extra) }
      end

      assert_equal 1, pushed.size
      assert_includes pushed.first[:body], "Garage code"
      assert_not_includes pushed.first[:body], "4821"
    end
  end

  test "entry values, entry notes and scratchpad notes are filtered from the logs" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    filtered = filter.filter(
      "family_reference"   => { "title" => "Garage code", "value" => "4821", "notes" => "side door" },
      "family_andie_entry" => { "title" => "Allergies",   "value" => "Penicillin", "notes" => "rash" },
      "family_rae_entry"   => { "title" => "Microchip",   "value" => "985112", "notes" => "HomeAgain" },
      "family_note"        => { "title" => "Gift ideas",  "body" => "a secret" }
    )

    assert_equal "Garage code", filtered["family_reference"]["title"]
    %w[family_reference family_andie_entry family_rae_entry].each do |key|
      assert_equal "[FILTERED]", filtered[key]["value"], key
      assert_equal "[FILTERED]", filtered[key]["notes"], key
    end
    assert_equal "[FILTERED]", filtered["family_note"]["title"]
    assert_equal "[FILTERED]", filtered["family_note"]["body"]
  end
end
