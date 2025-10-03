require 'rails_helper'

RSpec.describe StarlingController, type: :controller do
  describe '#receive' do
    subject { post :receive, body: body.to_json, format: :json }
    let(:body) { {} }

    context 'when a URL_SECRET is set, but none is passed' do
      before { allow(ENV).to receive(:[]).with('URL_SECRET').and_return('SECRET') }
      it { is_expected.to have_http_status(401) }
      it { is_expected.to have_json('error' => 'unauthorised') }
    end

    context 'when a URL_SECRET is set, but and is passed' do
      before { allow(ENV).to receive(:[]).with('URL_SECRET').and_return('SECRET') }

      before { allow(ENV).to receive(:[]).with('YNAB_STARLING_ACCOUNT_ID').and_return('response') }
      before { allow(ENV).to receive(:[]).with('YNAB_ACCESS_TOKEN').and_return('response') }
      before { allow(ENV).to receive(:[]).with('YNAB_BUDGET_ID').and_return('response') }
      before { allow(ENV).to receive(:[]).with('SKIP_FOREIGN_CURRENCY_FLAG').and_return('response') }
      before { allow(ENV).to receive(:[]).with('OMIT_IMPORT_ID').and_return(nil) }

      subject { post :receive, body: body.to_json, format: :json, params: { secret: 'SECRET' } }
      it { is_expected.to have_http_status(200) }
      it { is_expected.to have_json('warning' => 'unsupported_type') }
    end

    context 'when sending no body' do
      it { is_expected.to have_http_status(200) }
      it { is_expected.to have_json('warning' => 'unsupported_type') }
    end

    context 'when sending an unsupported webhook type' do
      let(:body) { { type: :not_supported } }
      it { is_expected.to have_http_status(200) }
      it { is_expected.to have_json('warning' => 'unsupported_type') }
    end

    context 'with OMIT_IMPORT_ID environment variable' do
      let(:webhook_double) { double('webhook', import: { id: 'test-id' }) }
      
      before do
        allow(JSON).to receive(:parse).and_return({})
        allow(F2ynab::YNAB::Client).to receive(:new).and_return(double('client'))
        allow(F2ynab::Webhooks::Starling).to receive(:new).and_return(webhook_double)
        allow(ENV).to receive(:[]).with('YNAB_ACCESS_TOKEN').and_return('token')
        allow(ENV).to receive(:[]).with('YNAB_BUDGET_ID').and_return('budget')
        allow(ENV).to receive(:[]).with('YNAB_STARLING_ACCOUNT_ID').and_return('account')
        allow(ENV).to receive(:[]).with('SKIP_FOREIGN_CURRENCY_FLAG').and_return(nil)
      end

      context 'when OMIT_IMPORT_ID is not set' do
        before do
          allow(ENV).to receive(:[]).with('URL_SECRET').and_return(nil)
          allow(ENV).to receive(:[]).with('OMIT_IMPORT_ID').and_return(nil)
        end

        it 'passes omit_import_id: false to webhook' do
          expect(F2ynab::Webhooks::Starling).to receive(:new).with(
            anything, anything, hash_including(omit_import_id: false)
          ).and_return(webhook_double)
          post :receive, body: '{}', format: :json
        end
      end

      context 'when OMIT_IMPORT_ID is set' do
        before do
          allow(ENV).to receive(:[]).with('URL_SECRET').and_return(nil)
          allow(ENV).to receive(:[]).with('OMIT_IMPORT_ID').and_return('true')
        end

        it 'passes omit_import_id: true to webhook' do
          expect(F2ynab::Webhooks::Starling).to receive(:new).with(
            anything, anything, hash_including(omit_import_id: true)
          ).and_return(webhook_double)
          post :receive, body: '{}', format: :json
        end
      end
    end
  end
end
