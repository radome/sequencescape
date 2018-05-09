# frozen_string_literal: true

# This file is part of SEQUENCESCAPE is distributed under the terms of GNU General Public License version 1 or later;
# Please refer to the LICENSE and README files for information on licensing and
# authorship of this file.
# Copyright (C) 2018 Genome Research Ltd.

##
# Helper module for tests using requiring stub methods for the LabWhere client endpoints.
module LabWhereClientHelper
  def create_location(locn_barcode, locn_name, locn_parentage)
    LabWhereClient::Location.new(
      'barcode' => locn_barcode,
      'name' => locn_name,
      'parentage' => locn_parentage
    )
  end

  def create_labware(lw_barcode, lw_locn_name, lw_locn_parentage)
    LabWhereClient::Labware.new(
      'barcode' => lw_barcode,
      'location' => {
        'name' => lw_locn_name,
        'parentage' => lw_locn_parentage
      }
    )
  end

  def stub_lwclient_labware_find_by_bc(lw_params)
    allow(LabWhereClient::Labware).to receive(:find_by_barcode)
      .with(lw_params[:lw_barcode])
      .and_return(
        create_labware(lw_params[:lw_barcode], lw_params[:lw_locn_name], lw_params[:lw_locn_parentage])
      )
  end

  def stub_lwclient_locn_find_by_bc(locn_params)
    allow(LabWhereClient::Location).to receive(:find_by_barcode)
      .with(locn_params[:locn_barcode])
      .and_return(
        if locn_params[:locn_name].nil?
          nil
        else
          create_location(locn_params[:locn_barcode], locn_params[:locn_name], locn_params[:locn_parentage])
        end
      )
  end

  def stub_lwclient_locn_children(locn_barcode, child_locns)
    allow(LabWhereClient::Location).to receive(:children)
      .with(locn_barcode)
      .and_return(
        child_locns.map do |child_locn|
          create_location(child_locn[:locn_barcode], child_locn[:locn_name], child_locn[:parentage])
        end
      )
  end

  def stub_lwclient_locn_labwares(locn_barcode, locn_labwares)
    allow(LabWhereClient::Location).to receive(:labwares)
      .with(locn_barcode)
      .and_return(
        locn_labwares.map do |locn_labware|
          create_labware(locn_labware[:lw_barcode], locn_labware[:lw_locn_name], locn_labware[:lw_locn_parentage])
        end
      )
  end
end