class Portfolio::SourceDocumentsController < Portfolio::BaseController
  before_action :set_doc, only: %i[show update destroy promote]

  # GET /portfolio/inbox  — triage view with filters and grouping
  def index
    @docs = Portfolio::SourceDocument.by_date.includes(:project, files_attachments: :blob)
    @f = params.permit(:status, :source, :property, :vendor, :year, :flag, :kind, :group, :q, :sort, :view).to_h
    @f["status"] = "unreviewed" if @f["status"].nil?
    @docs = @docs.where(status: @f["status"]) if @f["status"].present? && @f["status"] != "all"
    @docs = @docs.where(source: @f["source"]) if @f["source"].present?
    @docs = @docs.where(property_guess: (@f["property"] == "none" ? [nil, ""] : @f["property"])) if @f["property"].present?
    @docs = @docs.where(vendor: @f["vendor"]) if @f["vendor"].present?
    @docs = @docs.where(kind: @f["kind"]) if @f["kind"].present?
    @docs = @docs.where(suggested_group: @f["group"]) if @f["group"].present?
    @docs = @docs.where("extract(year from occurred_on) = ?", @f["year"].to_i) if @f["year"].present?
    @docs = @docs.where("flags ILIKE ?", "%#{@f['flag']}%") if @f["flag"].present?
    if @f["q"].present?
      q = "%#{@f['q']}%"
      @docs = @docs.where("title ILIKE :q OR vendor ILIKE :q OR description ILIKE :q OR metadata::text ILIKE :q", q: q)
    end
    @docs = @docs.reorder(amount: :desc) if @f["sort"] == "amount"

    base = Portfolio::SourceDocument.all
    @counts = {
      status:   base.group(:status).count,
      source:   base.group(:source).count,
      property: base.group(:property_guess).count,
      year:     base.where.not(occurred_on: nil).group("extract(year from occurred_on)::int").count.sort.reverse.to_h,
      kind:     base.group(:kind).count,
      group:    base.where(status: %w[unreviewed keep]).group(:suggested_group).count.sort_by { |k, v| [-v, k.to_s] }.to_h
    }
    @vendors  = base.where.not(vendor: [nil, ""]).group(:vendor).count.sort_by { |_, v| -v }.first(40)
    @projects = Portfolio::Project.includes(:property).by_date
    @grouped  = @docs.to_a.group_by { |d| d.suggested_group.presence || "Ungrouped" }
  end

  def show
    @projects = Portfolio::Project.includes(:property).by_date
    @neighbors = Portfolio::SourceDocument.where(vendor: @doc.vendor).where.not(id: @doc.id).by_date.limit(8)
  end

  def update
    attrs = params.require(:portfolio_source_document).permit(:status, :project_id, :work_item_id, :notes, :property_guess, :kind, :title, :vendor, :amount, :occurred_on, :flags, :suggested_group)
    attrs[:status] = "keep" if attrs[:project_id].present? && attrs[:status].blank? && @doc.status == "unreviewed"
    if @doc.update(attrs)
      redirect_back fallback_location: portfolio_inbox_path, notice: "Saved."
    else
      redirect_back fallback_location: portfolio_inbox_path, alert: @doc.errors.full_messages.to_sentence
    end
  end

  # POST /portfolio/source_documents/bulk
  # params: ids[], act = keep|discard|unreview|assign|create_project|delete, project_id, new_title, new_property_id
  def bulk
    ids  = Array(params[:ids]).map(&:to_i)
    docs = Portfolio::SourceDocument.where(id: ids)
    n = docs.count
    case params[:act]
    when "keep"     then docs.update_all(status: "keep", updated_at: Time.zone.now)
    when "discard"  then docs.update_all(status: "discard", updated_at: Time.zone.now)
    when "unreview" then docs.update_all(status: "unreviewed", project_id: nil, updated_at: Time.zone.now)
    when "assign"
      project = Portfolio::Project.find(params[:project_id])
      docs.update_all(project_id: project.id, status: "keep", updated_at: Time.zone.now)
    when "create_project"
      property = Portfolio::Property.find(params[:new_property_id])
      dates = docs.where.not(occurred_on: nil).pluck(:occurred_on)
      project = Portfolio::Project.create!(property: property, title: params[:new_title].presence || "New project",
                                           started_on: dates.min, completed_on: dates.max, status: "completed",
                                           summary: "Created from #{n} inbox documents")
      docs.update_all(project_id: project.id, status: "keep", updated_at: Time.zone.now)
      return redirect_to portfolio_project_path(project), notice: "Project created with #{n} documents."
    when "promote"
      done = 0
      docs.where.not(project_id: nil).find_each do |d|
        as = d.image_files.any? && d.document_files.empty? ? "photos" : (%w[permit plans contract].include?(d.kind) ? "document" : "expense")
        begin
          d.promote!(as: as); done += 1
        rescue => e
          Rails.logger.warn("promote failed for #{d.id}: #{e.message}")
        end
      end
      return redirect_back fallback_location: portfolio_inbox_path, notice: "Promoted #{done} of #{n} into their projects."
    when "delete"   then docs.destroy_all
    else
      return redirect_back fallback_location: portfolio_inbox_path, alert: "Unknown action."
    end
    redirect_back fallback_location: portfolio_inbox_path, notice: "#{n} document#{'s' unless n == 1} updated."
  end

  # POST /portfolio/source_documents/:id/promote?as=expense|document|photos
  def promote
    rec = @doc.promote!(as: params[:as])
    redirect_to portfolio_project_path(@doc.project), notice: "Added to project as #{params[:as]}."
  rescue => e
    redirect_back fallback_location: portfolio_source_document_path(@doc), alert: e.message
  end

  def destroy
    @doc.destroy
    redirect_to portfolio_inbox_path, notice: "Deleted."
  end

  def export_csv
    headers = %w[id status source source_ref occurred_on vendor title property_guess suggested_group kind amount flags project files notes]
    rows = Portfolio::SourceDocument.by_date.includes(:project, files_attachments: :blob).map do |d|
      [d.id, d.status, d.source, d.source_ref, d.occurred_on, d.vendor, d.title, d.property_guess, d.suggested_group, d.kind, d.amount, d.flags,
       d.project&.title, d.files.map { |f| f.filename.to_s }.join("; "), d.notes]
    end
    send_csv("inbox", headers, rows)
  end

  private

  def set_doc
    @doc = Portfolio::SourceDocument.find(params[:id])
  end
end
