class Portfolio::ExpensesController < Portfolio::NestedController
  before_action :set_project, only: %i[new create export_csv]

  def export_csv
    headers = %w[id purchased_on description amount category source vendor work_item invoice_number notes receipts]
    rows = @project.expenses.includes(:vendor, :work_item, receipts_attachments: :blob).map do |e|
      [e.id, e.purchased_on, e.description, e.amount, e.category, e.source, e.vendor&.name, e.work_item&.title,
       e.invoice_number, e.notes, e.receipts.map(&:filename).join("; ")]
    end
    send_csv("expenses-project-#{@project.id}", headers, rows)
  end

  private

  def model = Portfolio::Expense

  def record_params
    params.require(:portfolio_expense).permit(:purchased_on, :amount, :description, :category, :source, :vendor_id, :work_item_id, :invoice_number, :notes, receipts: [])
  end
end
