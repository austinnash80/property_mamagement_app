class Portfolio::WorkItemsController < Portfolio::NestedController
  private

  def model = Portfolio::WorkItem

  def record_params
    params.require(:portfolio_work_item).permit(:title, :trade, :description, :performed_by, :vendor_id, :started_on, :completed_on, :hours, :notes, :position)
  end
end
