# The family calendar: a month grid of events, plus what is coming up.
class Family::EventsController < Family::BaseController
  before_action :set_event, only: %i[show edit update destroy]

  def index
    @month      = month_from(params[:month])
    @grid_range = @month.beginning_of_week(:sunday)..@month.end_of_month.end_of_week(:sunday)

    # One entry per day the event covers, so multi-day events show on each day.
    @events_by_day = Hash.new { |h, k| h[k] = [] }
    Family::Event.occurrences_between(@grid_range).each do |event|
      first_day = [event.starts_on, @grid_range.first].max
      last_day = [event.last_day, @grid_range.last].min
      (first_day..last_day).each { |day| @events_by_day[day] << event }
    end

    @upcoming     = Family::Event.upcoming_occurrences
  end

  def show
    @people = User.by_name
    @display_event = @occurrence || @event
  end

  def new
    @people = User.by_name
    @event  = Family::Event.new(starts_on: date_param || Family.today, person: current_user)
  end

  def edit
    @people = User.by_name
    @event = occurrence_record if @occurrence
  end

  def create
    @event = Family::Event.new(event_params.merge(created_by: current_user))
    if @event.save
      notify_others_about("event", @event.title, url: family_event_path(@event),
                          detail: [@event.first_occurrence_on.strftime("%a %b %-d"), (@event.all_day? ? nil : @event.time_label)].compact.join(", "))
      redirect_to family_calendar_path(month: @event.first_occurrence_on.strftime("%Y-%m")), notice: "Event added."
    else
      @people = User.by_name
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @event = occurrence_record if @occurrence
    attributes = event_params
    attributes = attributes.except(:repeat_frequency, :repeat_until, :repeat_weekday, :repeat_day_of_month) if @occurrence
    if @event.update(attributes)
      redirect_to family_event_path(@series || @event, occurrence_on: @occurrence&.original_on), notice: "Event updated."
    else
      @people = User.by_name
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    month = (@occurrence || @event).starts_on.strftime("%Y-%m")
    if @occurrence
      occurrence_record.update!(cancelled: true)
    else
      @event.destroy
    end
    redirect_to family_calendar_path(month: month), notice: "Event deleted."
  end

  private

  def set_event
    @event = Family::Event.series.find(params[:id])
    return unless @event.repeating? && params[:occurrence_on].present?
    @series = @event
    day = Date.iso8601(params[:occurrence_on])
    @occurrence = @series.occurrence_on(day)
    raise ActiveRecord::RecordNotFound unless @occurrence
  rescue ArgumentError, TypeError
    raise ActiveRecord::RecordNotFound
  end

  def occurrence_record
    @series.recurrence_overrides.find_by(original_on: @occurrence.original_on) ||
      @series.recurrence_overrides.build(
        @series.attributes.slice("title", "start_time", "end_time", "location", "notes", "person_id", "created_by_id").merge(
          starts_on: @occurrence.starts_on, ends_on: @occurrence.ends_on,
          original_on: @occurrence.original_on, repeat_frequency: "none"
        )
      )
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
          .permit(:title, :starts_on, :ends_on, :start_time, :end_time, :location, :notes, :person_id, :repeat_frequency, :repeat_until, :repeat_weekday, :repeat_day_of_month)
  end
end
