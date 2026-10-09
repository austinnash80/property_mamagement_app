require "test_helper"

class Family::ReferencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "family-test@example.com", password: "test-pass", role: "family")
    post login_path, params: { email: @user.email, password: "test-pass" }
  end

  test "streaming services is offered as a category and accepts an entry" do
    get family_references_path
    assert_response :success
    assert_select "select#family_reference_category option", text: "Streaming services"

    assert_difference -> { Family::Reference.count }, 1 do
      post family_references_path, params: { family_reference: { title: "Netflix", category: "Streaming services" } }
    end
    assert_redirected_to family_references_path
    assert_equal "Streaming services", Family::Reference.last.category
  end
end
