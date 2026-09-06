class Portfolio::DocumentsController < Portfolio::NestedController
  private

  def model = Portfolio::Document

  def record_params
    params.require(:portfolio_document).permit(:kind, :title, :issued_on, :notes, :file)
  end
end
