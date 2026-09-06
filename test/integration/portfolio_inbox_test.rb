require "test_helper"

class PortfolioInboxTest < ActionDispatch::IntegrationTest
  setup do
    @property = Portfolio::Property.create!(name: "Test House")
    @doc = Portfolio::SourceDocument.create!(source: "homedepot", source_ref: "X1|2024-07-11", occurred_on: Date.new(2024, 7, 11),
      vendor: "The Home Depot", title: "HD purchase", amount: 1614.14, kind: "receipt", flags: "FLOORING",
      suggested_group: "332/334 Playa · 2024 · FLOORING", metadata: { "line_items" => [{ "description" => "Vinyl plank", "qty" => 10, "unit_price" => 100, "line_total" => 1000 }] })
    @doc.files.attach(fixture_file_upload("portfolio_receipt.pdf", "application/pdf"))
  end

  test "inbox lists, filters and shows a document" do
    get portfolio_inbox_path
    assert_response :success
    assert_includes response.body, "HD purchase"
    get portfolio_inbox_path(flag: "FLOORING", year: 2024, status: "all")
    assert_response :success
    get portfolio_source_document_path(@doc)
    assert_response :success
    assert_includes response.body, "Vinyl plank"
  end

  test "bulk create project assigns docs, then promote creates an expense with the receipt" do
    post bulk_portfolio_source_documents_path, params: { ids: [@doc.id], act: "create_project", new_property_id: @property.id, new_title: "Playa flooring" }
    project = Portfolio::Project.last
    assert_redirected_to portfolio_project_path(project)
    assert_equal "keep", @doc.reload.status
    assert_equal project.id, @doc.project_id
    post promote_portfolio_source_document_path(@doc, as: "expense")
    assert_equal 1, project.expenses.count
    assert_equal 1, project.expenses.first.receipts.count
    assert_equal "expense", @doc.reload.metadata["promoted_as"]
    get portfolio_project_path(project)
    assert_response :success
    assert_includes response.body, "Source documents"
  end

  test "bulk discard and keep" do
    post bulk_portfolio_source_documents_path, params: { ids: [@doc.id], act: "discard" }
    assert_equal "discard", @doc.reload.status
    post bulk_portfolio_source_documents_path, params: { ids: [@doc.id], act: "keep" }
    assert_equal "keep", @doc.reload.status
  end
end
