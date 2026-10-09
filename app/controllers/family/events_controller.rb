# The family calendar. The month grid also shows task due dates, so one page
# answers "what's happening, and what's owed" for the week.
class Family::EventsController < Family::BaseController
  before_action :set_event, only: %i[show edit update destroy]

  def index
    @month      = month_from(params[:month])
    @grid_range = @month.beginning_of_week(:sunday)..@month.end_of_month.end_of_week(:sunday)

    # One entry per day the event covers, so multi-day events show on each day.
    @events_by_day = Hash.new { |h, k| h[k] = [] }
    Family::Event.overlapping(@grid_range).includes(:person).each do |event|
      event.days.each { |day| @events_by_day[day] << event if @grid_range.cover?(day) }
    end

    @tasks_by_day = Family::Task.unfinished.where(due_on: @grid_range).includes(:list).group_by(&:due_on)
    @upcoming     = Family::Event.upcoming.includes(:person).limit(8)
  end

  def show
    @people = User.by_name
  end

  def new
    @people = User.by_name
    @event  = Family::Event.new(starts_on: date_param || Family.today)
  end

  def edit
    @people = User.by_name
  end

  def create
    @event = Family::Event.new(event_params.merge(created_by: current_user))
    if @event.save
      notify_others_about("event", @event.title, url: family_event_path(@event),
                          detail: [@event.starts_on.strftime("%a %b %-d"), (@event.all_day? ? nil : @event.time_label)].compact.join(", "))
      redirect_to family_calendar_path(month: @event.starts_on.strftime("%Y-%m")), notice: "Event added."
    else
      @people = User.by_name
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @event.update(event_params)
      redirect_to family_event_path(@event), notice: "Event updated."
    else
      @people = User.by_name
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    month = @event.starts_on.strftime("%Y-%m")
    @event.destroy
    redirect_to family_calendar_path(month: month), notice: "Event deleted."
  end

  private

  def set_event
    @event = Family::Event.find(params[:id])
  end

  def date_param
    Date.parse(params[:date].to_s)
  rescue ArgumentError, TypeError
    nil
  end

  # "2026-11" -> that month; anything else -> this month.
  def month_from(param)
    Date.strptime(param.to_s, "%Y-%m").beginning_of_month
  rescue ArgumentError, TypeError
    Family.today.beginning_of_month
  end

  def event_params
    params.require(:family_event)
          .permit(:title, :starts_on, :ends_on, :start_time, :end_time, :location, :notes, :person_id)
  end
end
