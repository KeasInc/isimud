require 'spec_helper'

describe Isimud::Client do
  let(:client) { Isimud::Client.new }

  before do
    @exceptions_1    = Array.new
    @exceptions_2    = Array.new
    @return_status_1 = true
    @return_status_2 = false
  end

  describe 'exception handling' do
    let(:exception_handler_1) { Proc.new { |e| @exceptions_1 << e; @return_status_1 } }
    let(:exception_handler_2) { Proc.new { |e| @exceptions_2 << e; @return_status_2 } }
    let!(:exception) { double(:exception) }

    context 'with one handler added' do
      before do
        client.on_exception(&exception_handler_1)
        client.run_exception_handlers(exception)
      end

      it 'calls the exception handler' do
        expect(@exceptions_1).to include(exception)
      end
    end

    context 'with two handlers added' do
      before do
        client.on_exception(&exception_handler_1)
        client.on_exception(&exception_handler_2)
      end

      it 'calls both exception handlers' do
        client.run_exception_handlers(exception)
        expect(@exceptions_1).to include(exception)
        expect(@exceptions_2).to include(exception)
      end


      context 'with Isimud.retry_failures set to false' do
        before do
          Isimud.retry_failures = false
        end

        it 'does not requeue message' do
          expect(client.run_exception_handlers(exception)).to be_falsey
        end
      end

      context 'with Isimud.retry_failures set to true regardless of handler return status' do
        before do
          Isimud.retry_failures = true
        end

        it 'requeues message' do
          expect(client.run_exception_handlers(exception)).to be_truthy
        end
      end

      context 'with Isimud.retry_failures nil' do
        before do
          Isimud.retry_failures = nil
        end

        context 'and all exception handlers return truthy status' do
          before do
            @return_status_2 = true
          end

          it 'requeues message' do
            expect(client.run_exception_handlers(exception)).to be_truthy
          end
        end

        context 'and any exception handler returns falsey status' do
          it 'does not requeue message if any handler returns false' do
            expect(client.run_exception_handlers(exception)).to be_falsey
          end
        end
      end
    end
  end
end
