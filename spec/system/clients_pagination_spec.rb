require 'rails_helper'

# System spec for Pagy pagination on the Clients index (Phase 8).
# Uses rack_test driver (no Chrome/Chromium in this WSL environment).
#
# Creates 25 clients to exceed the default 20/page limit and asserts
# that page 1 shows only 20 rows and that the pagination navigation
# element is rendered.

RSpec.describe 'Clients pagination', type: :system do
  before do
    driven_by(:rack_test)
  end

  let(:user) { create(:user, :administrador) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
  end

  it 'paginates clients (25 total, 20 per page on page 1)' do
    # Create 25 clients with distinct, sortable full_names (A01..A25)
    25.times do |i|
      num = format('%02d', i + 1)
      create(:client, :ruc_client,
             full_name:       "Client A#{num}",
             document_number: "201#{format('%08d', i + 1)}")
    end

    visit clients_path

    # Page 1 should show exactly 20 client rows (table body tr elements with client id)
    client_rows = all('table tbody tr[id^="client_"]')
    expect(client_rows.count).to eq(20)

    # Pagy v43 series_nav renders a <nav> element with a class containing "series-nav"
    expect(page).to have_css('nav.series-nav')
  end

  it 'shows the second page when navigating forward' do
    25.times do |i|
      num = format('%02d', i + 1)
      create(:client, :ruc_client,
             full_name:       "Client A#{num}",
             document_number: "201#{format('%08d', i + 1)}")
    end

    visit clients_path(page: 2)

    # Page 2 should show the remaining 5 clients
    client_rows = all('table tbody tr[id^="client_"]')
    expect(client_rows.count).to eq(5)
  end
end
