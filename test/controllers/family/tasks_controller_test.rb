require "test_helper"

class Family::TasksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "family-tasks@example.com", name: "Austin", password: "test-pass", role: "family")
    post login_path, params: { email: @user.email, password: "test-pass" }
    @list = Family::List.create!(name: "Home improvement")
    Family::Task.create!(list: @list, title: "Replace the faucet")
  end

  test "a blank quick-add goes back to the list with the error and the tasks still showing" do
    post family_tasks_path, params: { quick: 1, list: @list.id, family_task: { title: " ", list_id: @list.id } }
    assert_redirected_to family_tasks_path(list: @list.id)

    follow_redirect!
    assert_select ".alert-danger", text: "Title can't be blank"
    assert_select ".fa-task-title", text: "Replace the faucet"
  end

  test "a blank quick-add from the overview goes back to the overview" do
    post family_tasks_path, params: { quick: 1, from: "overview", family_task: { title: "", list_id: @list.id } }
    assert_redirected_to family_todo_path

    follow_redirect!
    assert_select ".alert-danger", text: "Title can't be blank"
    assert_select ".fa-card-title", text: "Replace the faucet"
  end

  test "quick-add title boxes are required, so the browser stops an empty add" do
    get family_todo_path
    assert_select "input[name='family_task[title]'][required]"
    get family_tasks_path(list: @list.id)
    assert_select "input[name='family_task[title]'][required]"
  end

  test "quick-add still adds a task" do
    assert_difference -> { Family::Task.count }, 1 do
      post family_tasks_path, params: { quick: 1, list: @list.id, family_task: { title: "Patch the hallway", list_id: @list.id } }
    end
    assert_redirected_to family_tasks_path(list: @list.id)
  end
end
