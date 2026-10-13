require "test_helper"

class Family::ArchivesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "family-archive@example.com", name: "Austin", password: "test-pass", role: "family")
    post login_path, params: { email: @user.email, password: "test-pass" }
    @list = Family::List.create!(name: "Archive test list")
    @task = Family::Task.create!(list: @list, title: "Keep this work", notes: "Measurements", assignee: @user, tags: "Archive-only")
  end

  test "archiving and restoring a completed task preserves all its details" do
    @task.complete!(@user)
    details = @task.reload.attributes.slice("notes", "assignee_id", "done_at", "done_by_id", "tags", "list_id")
    assert_no_difference -> { Family::Task.count } do
      delete family_task_path(@task)
    end
    assert @task.reload.archived_at
    assert_equal 0, Family::Task.active.where(id: @task.id).count
    get family_tasks_path
    assert_select ".fa-task-title", text: @task.title, count: 0
    get family_archive_path
    assert_select ".fa-task-title", text: @task.title
    assert_select "input[type=submit][value=?]", "Restore task"
    patch restore_family_task_path(@task)
    assert_redirected_to family_archive_path
    assert_nil @task.reload.archived_at
    assert_equal details, @task.attributes.slice(*details.keys)
    get family_tasks_path
    assert_select ".fa-task-title", text: @task.title
  end

  test "restoring a list retains individually archived tasks in the archive" do
    separately_archived = Family::Task.create!(list: @list, title: "Archived separately")
    delete family_task_path(separately_archived)
    assert_no_difference -> { Family::List.count + Family::Task.count } do
      delete family_list_path(@list)
    end
    assert @list.reload.archived_at
    assert_nil @task.reload.archived_at
    assert_equal 0, Family::Task.active.where(list_id: @list.id).count
    assert_not_includes Family::Task.all_tags, "Archive-only"
    get family_todo_path
    assert_select ".fa-card-name", text: @list.name, count: 0
    get family_lists_path
    assert_select "option", text: @list.name, count: 0
    get family_archive_path
    assert_select ".fa-task-title", text: @list.name
    assert_select ".fa-task-title", text: @task.title
    assert_select "input[type=submit][value=?]", "Restore list"
    patch restore_family_task_path(@task)
    assert_redirected_to family_archive_path
    assert_equal "Restore the list before restoring its tasks.", flash[:alert]
    assert @list.reload.archived_at
    patch restore_family_list_path(@list)
    assert_nil @list.reload.archived_at
    assert_includes Family::Task.active, @task
    assert_not_includes Family::Task.active, separately_archived
    assert_equal "Measurements", @task.reload.notes
    assert_equal @user.id, @task.assignee_id
    assert_equal 1, @list.open_count
    get family_root_path
    assert_select ".card-text", text: /1 open task.*1 assigned to you/m
    get family_todo_path
    assert_select ".fa-card-title", text: @task.title
    assert_select ".fa-card-title", text: separately_archived.title, count: 0
    patch restore_family_task_path(separately_archived)
    assert_includes Family::Task.active, separately_archived.reload
  end

  test "archived work cannot be edited or completed or receive new tasks" do
    delete family_list_path(@list)
    assert_raises(ActiveRecord::RecordNotFound) { get edit_family_list_path(@list) }
    assert_raises(ActiveRecord::RecordNotFound) { get family_task_path(@task) }
    assert_raises(ActiveRecord::RecordNotFound) { patch toggle_family_task_path(@task) }
    assert_nil @task.reload.done_at
    assert_no_difference -> { Family::Task.count } do
      post family_tasks_path, params: { family_task: { title: "New work", list_id: @list.id } }
    end
    assert_response :unprocessable_entity
    assert_select ".alert-danger", text: /List is archived/
    assert_raises(ActiveRecord::RecordNotFound) { get family_tasks_path(list: @list.id) }
  end

  test "archive actions are repeatable and preserve their original timestamp" do
    delete family_task_path(@task)
    archived_at = @task.reload.archived_at
    delete family_task_path(@task)
    assert_equal archived_at, @task.reload.archived_at
    delete family_list_path(@list)
    archived_at = @list.reload.archived_at
    delete family_list_path(@list)
    assert_equal archived_at, @list.reload.archived_at
    2.times { patch restore_family_list_path(@list) }
    2.times { patch restore_family_task_path(@task) }
    assert_nil @list.reload.archived_at
    assert_nil @task.reload.archived_at
  end

  test "anonymous requests cannot browse or restore archived work" do
    delete family_list_path(@list)
    anonymous = open_session
    anonymous.get family_archive_path
    assert_equal "http://www.example.com/login", anonymous.response.location
    anonymous.patch restore_family_list_path(@list)
    assert_equal 302, anonymous.response.status
    assert @list.reload.archived_at
  end
end
