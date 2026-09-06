require "test_helper"

# End-to-end coverage for the Project Portfolio section (independent of the
# property-management tables, so no fixtures are needed).
class PortfolioFlowTest < ActionDispatch::IntegrationTest
  setup do
    @property = Portfolio::Property.create!(name: "Test House", address: "1 Main St", property_type: "residential")
    @vendor   = Portfolio::Vendor.create!(name: "Test Plumbing", trade: "Plumbing")
  end

  test "create project, work item, expense with receipts, bulk photos, document" do
    post portfolio_projects_path, params: { portfolio_project: { property_id: @property.id, title: "Kitchen remodel", started_on: "2021-06-01", status: "completed" } }
    project = Portfolio::Project.last
    assert_redirected_to portfolio_project_path(project)

    post portfolio_project_work_items_path(project), params: { portfolio_work_item: { title: "Rough plumbing", trade: "Plumbing", performed_by: "sub", vendor_id: @vendor.id, hours: "6" } }
    assert_equal 1, project.work_items.count
    work_item = project.work_items.first

    post portfolio_project_expenses_path(project), params: { portfolio_expense: {
      purchased_on: "2021-06-03", amount: "125.50", description: "PEX + fittings", source: "Home Depot", category: "materials",
      work_item_id: work_item.id, receipts: [fixture_file_upload("portfolio_receipt.pdf", "application/pdf"), fixture_file_upload("portfolio_sample.jpg", "image/jpeg")] } }
    expense = project.expenses.first
    assert_equal 2, expense.receipts.count
    assert_equal 125.5, project.total_cost.to_f

    post portfolio_project_photos_path(project), params: { portfolio_photo: {
      stage: "before", caption: "Old", taken_on: "2021-05-30",
      images: [fixture_file_upload("portfolio_sample.jpg", "image/jpeg"), fixture_file_upload("portfolio_sample.jpg", "image/jpeg"), fixture_file_upload("portfolio_sample.jpg", "image/jpeg")] } }
    assert_redirected_to portfolio_project_path(project, anchor: "photos")
    assert_equal 3, project.photos.count
    assert project.photos.all? { |p| p.image.attached? && p.stage == "before" }

    post portfolio_project_documents_path(project), params: { portfolio_document: { kind: "permit", title: "Permit", file: fixture_file_upload("portfolio_receipt.pdf", "application/pdf") } }
    assert_equal 1, project.documents.count

    get portfolio_project_path(project)
    assert_response :success
    assert_includes response.body, "Kitchen remodel"
    assert_includes response.body, "Test Plumbing"
    assert_includes response.body, "$125.50"

    get portfolio_property_path(@property)
    assert_response :success
    get portfolio_projects_path
    assert_response :success
    get portfolio_vendor_path(@vendor)
    assert_response :success
    get export_csv_portfolio_project_expenses_path(project)
    assert_response :success
    assert_includes response.body, "PEX + fittings"
  end

  test "photo upload with no images re-renders the form" do
    project = Portfolio::Project.create!(property: @property, title: "P")
    post portfolio_project_photos_path(project), params: { portfolio_photo: { stage: "after" } }
    assert_response :unprocessable_entity
    assert_equal 0, project.photos.count
  end

  test "deleting a project removes its children" do
    project = Portfolio::Project.create!(property: @property, title: "P")
    project.work_items.create!(title: "W")
    project.expenses.create!(amount: 1)
    delete portfolio_project_path(project)
    assert_redirected_to portfolio_property_path(@property)
    assert_equal 0, Portfolio::WorkItem.count
    assert_equal 0, Portfolio::Expense.count
  end
end
