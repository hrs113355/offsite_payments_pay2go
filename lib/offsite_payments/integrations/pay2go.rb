require "offsite_payments"
require_relative "pay2go/version"

module OffsitePayments #:nodoc:
  module Integrations #:nodoc:
    module Pay2go
      mattr_accessor :service_url
      mattr_accessor :merchant_id
      mattr_accessor :hash_key
      mattr_accessor :hash_iv
      mattr_accessor :debug

      def self.service_url
        case OffsitePayments.mode
        when :production
          'https://api.pay2go.com/MPG/mpg_gateway'
        when :development
          'https://capi.pay2go.com/MPG/mpg_gateway'
        when :test
          'https://capi.pay2go.com/MPG/mpg_gateway'
        else
          raise StandardError, "Integration mode set to an invalid value: #{mode}"
        end
      end

      def self.notification(post)
        Notification.new(post)
      end

      def self.setup
        yield(self)
      end

      def self.fetch_url_encode_data(fields)
        check_fields = [:"Amt", :"MerchantID", :"MerchantOrderNo", :"TimeStamp", :"Version"]
        raw_data = fields.sort.map{|field, value|
          "#{field}=#{value}" if check_fields.include?(field.to_sym)
        }.compact.join('&')

        hash_raw_data = "HashKey=#{OffsitePayments::Integrations::Pay2go.hash_key}&#{raw_data}&HashIV=#{OffsitePayments::Integrations::Pay2go.hash_iv}"

        sha256 = Digest::SHA256.new
        sha256.update hash_raw_data.force_encoding("utf-8")
        sha256.hexdigest.upcase
      end

      class Helper < OffsitePayments::Helper
        def initialize(order, account, options = {})
          super
          add_field 'MerchantID', merchant_id
        end

        ### 常見介面
        # 廠商編號
        mapping :merchant_id, 'MerchantID'
        mapping :account, 'MerchantID' # AM common
        # 回傳格式
        mapping :respond_type, 'RespondType'
        # 時間戳記
        mapping :time_stamp, 'TimeStamp'
        # 串接程式版本
        mapping :version, 'Version'
        # 語系 (no required)
        mapping :lang_type, 'LangType'
        # 廠商交易編號
        mapping :merchant_order_no, 'MerchantOrderNo'
        mapping :order, 'MerchantOrderNo' # AM common
        # 交易金額（幣別：新台幣）
        mapping :amt, 'Amt'
        mapping :amount, 'Amt' # AM common
        # 商品資訊（限制長度50字）
        mapping :item_desc, 'ItemDesc'
        # 交易限制秒數，下限是 60 秒，上限 900 秒 (no required)
        mapping :trade_limit, 'TradeLimit'
        # 繳費有限期限，格式範例：20140620
        mapping :expire_date, 'ExpireDate'
        # 支付完成返回商店網址（沒給會留在智付寶畫面）
        mapping :return_url, 'ReturnURL'
        # 支付通知網址
        mapping :notify_url, 'NotifyURL'
        # 商店取號網址（沒給的話取號後會留在智付寶畫面）
        mapping :customer_url, 'CustomerURL'
        # 支付取消返回商店網址（交易取消後平台會出現返回鈕）
        mapping :client_back_url, 'ClientBackURL'
        # 付款人電子信箱
        mapping :email, 'Email'
        # 付款人電子信箱是否開放修改（預設為可修改，給0, 1）
        mapping :email_odify, 'EmailModify'
        # 智付寶會員（預設1則需要登入智付寶）
        mapping :login_type, 'LoginType'
        # 商店備註
        mapping :order_comment, 'OrderComment'
        # 信用卡一次付清啟用（1為啟用）
        mapping :credit, 'CREDIT'
        # 信用卡紅利啟用（1為啟用）
        mapping :credit_red, 'CreditRed'
        # 信用卡分期付款啟用
        mapping :inst_flag, 'InstFlag'
        # 信用卡銀聯卡啟用
        mapping :union_pay, 'UNIONPAY'
        # WebATM 啟用
        mapping :web_atm, 'WEBATM'
        # ATM 轉帳啟用
        mapping :vacc, 'VACC'
        # 超商代碼繳費啟用
        mapping :cvs, 'CVS'
        # 條碼繳費啟用
        mapping :barcode, 'BARCODE'
        # 自訂支付啟用
        mapping :custom, 'CUSTOM'
        # 付款人綁定資料（快速結帳參數）
        mapping :token_term, 'TokenTerm'

        def encrypted_data
          url_encrypted_data = fetch_url_encode_data(@fields)

          add_field 'CheckValue', url_encrypted_data
        end

      end

      class Notification < OffsitePayments::Notification
        attr_accessor :_params

        def _params
          if @_params.nil?
            if @params.key?("JSONData") # json response type
              # puts params['JSONData'].to_s
              @_params = JSON.parse(@params['JSONData'].to_s)
              # puts JSON.parse(@_params['Result'])['Amt']
              @_params = @_params.merge(JSON.parse(@_params['Result']))
            else # string response type
              @_params = @params
            end
          end
          @_params
        end

        # TODO 使用查詢功能實作 acknowledge
        # 而以 checksum_ok? 代替
        def acknowledge
          checksum_ok?
        end

        def complete?
          case status
          when 'SUCCESS' # 付款/取號成功
            true
          end
        end

        def checksum_ok?
          params_copy = _params.clone

          check_fields = [:"Amt", :"MerchantID", :"MerchantOrderNo", :"TradeNo"]
          raw_data = params_copy.sort.map{|field, value|
            "#{field}=#{value}" if check_fields.include?(field.to_sym)
          }.compact.join('&')

          hash_raw_data = "HashIV=#{OffsitePayments::Integrations::Pay2go.hash_iv}&#{raw_data}&HashKey=#{OffsitePayments::Integrations::Pay2go.hash_key}"

          sha256 = Digest::SHA256.new
          sha256.update hash_raw_data.force_encoding("utf-8")
          (sha256.hexdigest.upcase == check_code.to_s)
        end

        def status
          _params['Status']
        end

        def message
          URI.decode(_params['Message'])
        end

        def merchant_id
          _params['MerchantID']
        end

        def amt
          _params['Amt'].to_s
        end

        # 訂單號碼
        def item_id
          merchant_order_no
        end

        # Pay2go 端訂單號碼
        def transaction_id
          trade_no
        end

        def trade_no
          _params['TradeNo']
        end

        def merchant_order_no
          _params['MerchantOrderNo']
        end

        def payment_type
          _params['PaymentType']
        end

        def respond_type
          _params['RespondType']
        end

        def check_code
          _params['CheckCode']
        end

        def pay_time
          URI.decode(_params['PayTime']).gsub("+", " ")
        end

        def ip
          _params['IP']
        end

        def escrow_bank
          _params['EscrowBank']
        end

        # credit card
        def respond_code
          _params['RespondCode']
        end

        def auth
          _params['Auth']
        end

        def card_6no
          _params['Card6No']
        end

        def card_4no
          _params['Card4No']
        end

        def inst
          _params['Inst']
        end

        def inst_first
          _params['InstFirst']
        end

        def inst_each
          _params['InstEach']
        end

        def eci
          _params['ECI']
        end

        def token_use_status
          _params['TokenUseStatus']
        end

        # web atm, atm
        def pay_bank_code
          _params['PayBankCode']
        end

        def payer_account_5code
          _params['PayerAccount5Code']
        end

        # cvs
        def code_no
          _params['CodeNo']
        end

        # barcode
        def barcode_1
          _params['Barcode_1']
        end

        def barcode_2
          _params['Barcode_2']
        end

        def barcode_3
          _params['Barcode_3']
        end

        # other about serials
        def expire_date
          _params['ExpireDate']
        end

      end
    end
  end
end
