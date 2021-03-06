module Worker
  class DepositEtc
    def logger(attribute, payload)
      logger ||= Logger.new("#{Rails.root}/log/deposit_etc.log")
      logger.debug attribute
      logger.debug payload
    end
    def process(payload, metadata, delivery_info)
      payload.symbolize_keys!

      sleep 0.5 # nothing result without sleep by query gettransaction api

      txid = payload[:txid]
      # status = payload[:status]
      

      # logger ||= Logger.new("#{Rails.root}/log/my.log")
      # file = File.open("#{Rails.root}/tmp/my.txt", "w")
      # file.write(txid)
      # file.close
      logger "txid", txid

      channel_key = 'ethereumclassic'
      channel = DepositChannel.find_by_key(channel_key)
      raw     = get_raw_etc(txid)
      logger "raw", raw
      deposit_etc!(channel, txid, raw)
    end

    def deposit_etc!(channel, txid, raw)
      return if raw[:gas] == nil
      
      ActiveRecord::Base.transaction do
        unless PaymentAddress.where(currency: channel.currency_obj.id, address: raw[:address]).first
          Rails.logger.info "Deposit address not found, skip. txid: #{txid}, address: #{raw[:address]}, amount: #{raw[:amount]}"
          return
        end
        tx = PaymentTransaction::Normal.create! \
          txid: txid,
          txout: 0,
          address: raw[:address],
          amount: raw[:amount].to_s.to_d,
          confirmations: raw[:confirmations],
          receive_at: Time.now,
          currency: channel.currency
        deposit = channel.kls.create! \
          payment_transaction_id: tx.id,
          txid: tx.txid,
          txout: tx.txout,
          amount: tx.amount,
          member: tx.member,
          account: tx.account,
          currency: tx.currency,
          confirmations: tx.confirmations
        deposit.submit!
      end
    rescue
      Rails.logger.error "Failed to deposit: #{$!}"
      Rails.logger.error "txid: #{txid}, detail: #{detail.inspect}"
      Rails.logger.error $!.backtrace.join("\n")
    end
    def get_raw_etc(txid)
      @data_test = CoinRPC['etc'].eth_getTransactionByHash(["#{txid}"])
      address = @data_test["to"]
      value = @data_test["value"].to_i(16) / ((10**18)).to_d
      gas = @data_test["gas"].to_i(16)
      @details = {:amount => value.to_f, :confirmations => 0, :address => address, :gas => gas}
    end
  end
end
