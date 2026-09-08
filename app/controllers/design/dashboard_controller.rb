class Design::DashboardController < Design::BaseController
  def index
    @concepts = Design::Concept.ordered.includes(images: { file_attachment: :blob })
    @notes    = Design::Note.recent.includes(:concept).limit(6)
    @images   = Design::Image.recent.includes(:concept).with_attached_file.limit(12)
    @counts   = { concepts: Design::Concept.count, notes: Design::Note.count, images: Design::Image.count }
  end
end
