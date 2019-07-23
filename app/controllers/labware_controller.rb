# frozen_string_literal: true

# Handles viewing {Labware} information
# @see {Labware}
class LabwareController < ApplicationController
  before_action :discover_asset, only: %i[show edit update summary print_assets print history]

  def index
    if params[:study_id]
      @study = Study.find(params[:study_id])
      @assets = @study.assets_through_aliquots.order(:name).page(params[:page])
    else
      @assets = Labware.page(params[:page])
    end

    respond_to do |format|
      format.html
      if params[:study_id]
        format.xml { render xml: Study.find(params[:study_id]).assets_through_requests.to_xml }
      elsif params[:sample_id]
        format.xml { render xml: Sample.find(params[:sample_id]).assets.to_xml }
      elsif params[:asset_id]
        @asset = Labware.find(params[:asset_id])
        format.xml { render xml: ['relations' => { 'parents' => @asset.parents, 'children' => @asset.children }].to_xml }
      end
    end
  end

  def show
    @source_plate = @asset.source_plate
    respond_to do |format|
      format.html
      format.xml
      format.json { render json: @asset }
    end
  end

  def edit
    @valid_purposes_options = @asset.compatible_purposes.pluck(:name, :id)
  end

  def history
    respond_to do |format|
      format.html
      format.xml  { @request.events.to_xml }
      format.json { @request.events.to_json }
    end
  end

  def update
    respond_to do |format|
      if @asset.update(labware_params.merge(params.to_unsafe_h.fetch(:lane, {})))
        flash[:notice] = 'Labware was successfully updated.'
        if params[:lab_view]
          format.html { redirect_to(action: :lab_view, barcode: @asset.human_barcode) }
        else
          format.html { redirect_to(action: :show, id: @asset.id) }
          format.xml  { head :ok }
        end
      else
        format.html { render action: 'edit' }
        format.xml  { render xml: @asset.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @asset.destroy

    respond_to do |format|
      format.html { redirect_to(assets_url) }
      format.xml  { head :ok }
    end
  end

  def summary
    @summary = UiHelper::Summary.new(per_page: 25, page: params[:page])
    @summary.load_asset(@asset)
  end

  def print
    if @asset.printable?
      @printable = @asset.printable_target
      @direct_printing = (@asset.printable_target == @asset)
    else
      flash[:error] = "#{@asset.display_name} does not have a barcode so a label can not be printed."
      redirect_to asset_path(@asset)
    end
  end

  def print_labels
    print_job = LabelPrinter::PrintJob.new(params[:printer],
                                           LabelPrinter::Label::AssetRedirect,
                                           printables: params[:printables])
    if print_job.execute
      flash[:notice] = print_job.success
    else
      flash[:error] = print_job.errors.full_messages.join('; ')
    end

    redirect_to phi_x_url
  end

  def print_assets
    print_job = LabelPrinter::PrintJob.new(params[:printer],
                                           LabelPrinter::Label::AssetRedirect,
                                           printables: @asset)
    if print_job.execute
      flash[:notice] = print_job.success
    else
      flash[:error] = print_job.errors.full_messages.join('; ')
    end
    redirect_to asset_url(@asset)
  end

  def show_plate
    @asset = Plate.find(params[:id])
  end

  def new_request
    @request_types = RequestType.standard.active.applicable_for_asset(@asset)
    # In rare cases the user links in to the 'new request' page
    # with a specific study specified. In even rarer cases this may
    # conflict with the assets primary study.
    # ./features/7711055_new_request_links_broken.feature:29
    # This resolves the issue, but the code could do with a significant
    # refactor. I'm delaying this currently as we NEED to get SS434 completed.
    # 1. This should probably be RequestsController::new
    # 2. We should use Request.new(...) and form helpers
    # 3. This will allow us to instance_variable_or_id_param helpers.
    @study = if params[:study_id]
               Study.find(params[:study_id])
             else
               @asset.studies.first
             end
    @project = @asset.projects.first || @asset.studies.first&.projects&.first
  end

  def lookup
    return unless params[:asset] && params[:asset][:barcode]

    @assets = Labware.with_barcode(params[:asset][:barcode]).limit(50).page(params[:page])

    if @assets.size == 1
      redirect_to @assets.first
    elsif @assets.empty?
      flash.now[:error] = "No asset found with barcode #{params[:asset][:barcode]}"
      respond_to do |format|
        format.html { render action: 'lookup' }
        format.xml  { render xml: @assets.to_xml }
      end
    else
      respond_to do |format|
        format.html { render action: 'index' }
        format.xml  { render xml: @assets.to_xml }
      end
    end
  end

  def reset_values_for_move
    render layout: false
  end

  def find_by_barcode; end

  def lab_view
    barcode = params.fetch(:barcode, '').strip

    if barcode.blank?
      redirect_to action: 'find_by_barcode'
      return
    else
      @asset = Labware.find_from_barcode(barcode)
      redirect_to action: 'find_by_barcode', error: "Unable to find anything with this barcode: #{barcode}" if @asset.nil?
    end
  end

  private

  def labware_params
    permitted = %i[volume concentration]
    permitted << :name if current_user.administrator?
    permitted << :plate_purpose_id if current_user.administrator? || current_user.lab_manager?
    params.require(:labware).permit(permitted)
  end

  def discover_asset
    @asset = Labware.include_for_show.find(params[:id])
  end

  def check_valid_values(params = nil)
    if (params[:study_id_to] == '0') || (params[:study_id_from] == '0')
      flash[:error] = "You have to select 'Study From' and 'Study To'"
      return false
    else
      study_from = Study.find(params[:study_id_from])
      study_to = Study.find(params[:study_id_to])
      if study_to.name.eql?(study_from.name)
        flash[:error] = "You can't select the same Study."
        return false
      elsif params[:asset_group_id] == '0' && params[:new_assets_name].empty?
        flash[:error] = "You must indicate an 'Asset Group'."
        return false
      elsif params[:asset_group_id] != '0' && !params[:new_assets_name].empty?
        flash[:error] = 'You can select only an Asset Group!'
        return false
      elsif AssetGroup.find_by(name: params[:new_assets_name])
        flash[:error] = 'The name of Asset Group exists!'
        return false
      end
    end
    true
  end
end
