# frozen_string_literal: true

require 'rails_helper'

describe 'Labwhere reception', js: true do
  let(:user) { create :user, email: 'login@example.com' }
  let(:plate) { create :plate }

  it 'user can pool from different tubes to stock and standard mx tubes' do
    login_user user
    visit labwhere_receptions_path
    expect(page).to have_content 'Labwhere Reception'
    fill_in('User barcode or swipecard', with: 12345)
    click_on 'Update locations'
    expect(page).to have_content "Asset barcodes can't be blank"
    within('#new_labwhere_reception') do
      fill_in('asset_scan', with: plate.ean13_barcode).send_keys(:return)
      expect(find('.barcode_list')).to have_content plate.ean13_barcode
      expect(page).to have_content 'Scanned: 1'
      fill_in('asset_scan', with: 222).send_keys(:return)
      fill_in('asset_scan', with: 333).send_keys(:return)
      fill_in('asset_scan', with: 222).send_keys(:return)
      expect(page).to have_content(222, count: 1)
      expect(page).to have_content 'Scanned: 3'
      first('a', text: 'Remove from list').click
      first('a', text: 'Remove from list').click
      expect(page).to have_content 'Scanned: 1'
      first('a', text: 'Remove from list').click
      fill_in('asset_scan', with: plate.ean13_barcode).send_keys(:return)
      click_on 'Update locations'
    end
    expect(page).to have_content plate.human_barcode
    expect(page).to have_content plate.purpose.name
  end
end
