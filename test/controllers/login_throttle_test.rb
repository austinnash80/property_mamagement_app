require "test_helper"

class LoginThrottleTest < ActionDispatch::IntegrationTest
  setup do
    Rack::Attack.enabled = true
    Rack::Attack.reset!
    User.create!(email: "throttle@example.com", name: "Austin", password: "right-pass", role: "family")
  end

  teardown do
    Rack::Attack.reset!
    Rack::Attack.enabled = false
  end

  test "an address gets 10 tries in 15 minutes, then is told to wait" do
    10.times do
      post login_path, params: { email: "throttle@example.com", password: "wrong" }
      assert_response :unprocessable_entity
    end

    post login_path, params: { email: "throttle@example.com", password: "right-pass" }
    assert_response :too_many_requests
    assert_match "Too many sign-in attempts", response.body

    travel 16.minutes do
      post login_path, params: { email: "throttle@example.com", password: "right-pass" }
      assert_redirected_to family_root_path
    end
  end

  test "one account gets 20 tries a day, whatever address they come from" do
    20.times do |i|
      post login_path, params: { email: "throttle@example.com", password: "wrong" }, env: { "REMOTE_ADDR" => "203.0.113.#{i}" }
    end

    post login_path, params: { email: "Throttle@example.com", password: "right-pass" }, env: { "REMOTE_ADDR" => "198.51.100.7" }
    assert_response :too_many_requests
  end

  test "signing in is otherwise unaffected" do
    post login_path, params: { email: "throttle@example.com", password: "right-pass" }
    assert_redirected_to family_root_path
  end
end
