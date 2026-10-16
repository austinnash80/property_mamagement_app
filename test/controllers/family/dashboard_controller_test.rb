require "test_helper"

class Family::DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    user = User.create!(email: "family-dashboard@example.com", name: "Austin", password: "test-pass", role: "family")
    post login_path, params: { email: user.email, password: "test-pass" }
  end

  test "family pages display the Nash Family title" do
    [family_root_path, family_calendar_path].each do |path|
      get path
      assert_response :success
      assert_select "title", text: "Nash Family"
      assert_select ".fa-header h1 a[href=?]", family_root_path, text: "Nash Family"
      assert_select 'meta[name="apple-mobile-web-app-title"][content="Nash Family"]'
    end
  end
  test "Austin feature is removed from home and navigation" do
    [family_root_path, family_andie_entries_path].each do |path|
      get path
      assert_response :success
      assert_select "a[href^='/family/austin']", count: 0
      assert_select ".card-title", text: "Austin", count: 0
    end
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/family/austin", method: :get)
    end
  end

end
