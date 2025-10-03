require 'rails_helper'

RSpec.describe Starlingv2Controller, type: :controller do
  describe '#feed' do
    subject { post :feed, body: body.to_json, format: :json }
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

      subject { post :feed, body: body.to_json, format: :json, params: { secret: 'SECRET' } }
      it { is_expected.to have_http_status(200) }
      it { is_expected.to have_json('warning' => 'unsupported_type') }
    end

    context 'when sending no body' do
      before do
        allow(ENV).to receive(:[]).with('URL_SECRET').and_return(nil)
        allow(ENV).to receive(:[]).with('YNAB_STARLING_ACCOUNT_ID').and_return('response')
        allow(ENV).to receive(:[]).with('YNAB_ACCESS_TOKEN').and_return('response')
        allow(ENV).to receive(:[]).with('YNAB_BUDGET_ID').and_return('response')
        allow(ENV).to receive(:[]).with('SKIP_FOREIGN_CURRENCY_FLAG').and_return('response')
        allow(ENV).to receive(:[]).with('OMIT_IMPORT_ID').and_return(nil)
      end

      it { is_expected.to have_http_status(200) }
      it { is_expected.to have_json('warning' => 'unsupported_type') }
    end

    context 'when sending an unsupported source type' do
      let(:body) { { content: { source: 'UNSUPPORTED_SOURCE' } } }

      before do
        allow(ENV).to receive(:[]).with('URL_SECRET').and_return(nil)
        allow(ENV).to receive(:[]).with('YNAB_STARLING_ACCOUNT_ID').and_return('response')
        allow(ENV).to receive(:[]).with('YNAB_ACCESS_TOKEN').and_return('response')
        allow(ENV).to receive(:[]).with('YNAB_BUDGET_ID').and_return('response')
        allow(ENV).to receive(:[]).with('SKIP_FOREIGN_CURRENCY_FLAG').and_return('response')
        allow(ENV).to receive(:[]).with('OMIT_IMPORT_ID').and_return(nil)
      end

      it { is_expected.to have_http_status(200) }
      it { is_expected.to have_json('warning' => 'unsupported_type') }
    end

    context 'with OMIT_IMPORT_ID environment variable' do
      let(:valid_body) do
        {
          content: {
            source: 'MASTER_CARD',
            feedItemUid: 'test-feed-item-uid',
            transactionTime: '2023-01-01T12:00:00Z',
            amount: { minorUnits: 1000, currency: 'GBP' },
            direction: 'OUT',
            counterPartyName: 'Test Merchant',
            reference: 'Test Transaction'
          }
        }
      end
      let(:transaction_creator_double) { double('transaction_creator', create: { id: 'test-id' }) }
      
      before do
        allow(F2ynab::YNAB::Client).to receive(:new).and_return(double('client'))
        allow(F2ynab::YNAB::TransactionCreator).to receive(:new).and_return(transaction_creator_double)
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

        it 'passes the feed item UID as import_id' do
          expect(F2ynab::YNAB::TransactionCreator).to receive(:new).with(
            anything, hash_including(id: 'S:test-feed-item-uid')
          ).and_return(transaction_creator_double)
          post :feed, body: valid_body.to_json, format: :json
        end
      end

      context 'when OMIT_IMPORT_ID is set' do
        before do
          allow(ENV).to receive(:[]).with('URL_SECRET').and_return(nil)
          allow(ENV).to receive(:[]).with('OMIT_IMPORT_ID').and_return('true')
        end

        it 'passes nil as import_id' do
          expect(F2ynab::YNAB::TransactionCreator).to receive(:new).with(
            anything, hash_including(id: nil)
          ).and_return(transaction_creator_double)
          post :feed, body: valid_body.to_json, format: :json
        end
      end
    end
  end
end