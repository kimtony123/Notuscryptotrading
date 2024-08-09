local json = require("json")
local math = require("math")

_0RBIT = "BaMK1dfayo75s3q1ow6AO64UDpD9SEFbeE8xYrY2fyQ"
_0RBT_TOKEN = "BUhZLMwQ6yZHguLtJYA5lLUa9LQzLXMXRfaq9FVcPJc"

BASE_URL = "https://api.coingecko.com/api/v3/simple/price"
FEE_AMOUNT = "1000000000000" -- 1 $0RBT

TOKEN_PRICES = TOKEN_PRICES or {

    BTC = {
		coingecko_id = "bitcoin",
		price = 0,
		last_update_timestamp = 0
	},
	ETH = {
		coingecko_id = "ethereum",
		price = 0,
		last_update_timestamp = 0
	},
	SOL = {
		coingecko_id = "solana",
		price = 0,
		last_update_timestamp = 0
	}
}

ID_TOKEN = ID_TOKEN or {
    bitcoin = "BTC",
    ethereum = "ETH",
    solana = "SOL"
}
LOGS = LOGS or {}
Balances = Balances or {}

-- Credentials token
AOC = "pdKYJSk3n2XuFSt6AX-A7n_DhMmTWxCH3W8dxGBPXjM"

-- Table to track addresses that have requested tokens
RequestedAddresses = RequestedAddresses or {}

openTrades = openTrades or {}
expiredTrades = expiredTrades or {}
winners = winners or {}



function fetchPrice()
    local url
    local token_ids = ""

    for _, v in pairs(TOKEN_PRICES) do
        token_ids = token_ids .. v.coingecko_id .. ","
    end

    url = BASE_URL .. "?ids=" .. token_ids .. "&vs_currencies=usd"

    Send({
        Target = _0RBT_TOKEN,
        Action = "Transfer",
        Recipient = _0RBIT,
        Quantity = FEE_AMOUNT,
        ["X-Url"] = url,
        ["X-Action"] = "Get-Real-Data"
    })
    print("GET Request sent to the 0rbit process.")
end

function receiveData(msg)
    local res = json.decode(msg.Data)
    for k, v in pairs(res) do
        TOKEN_PRICES[k].price = tonumber(v.usd)
        TOKEN_PRICES[k].last_update_timestamp = msg.Timestamp
    end
end

function getTokenPrice(msg)
    local token = msg.Tags.Token
    local price = TOKEN_PRICES[token].price
    if price == 0 then
        Handlers.utils.reply("Price not available!!!")(msg)
    else
        Handlers.utils.reply(tostring(price))(msg)
    end
end

function tableToJson(tbl)
    local result = {}
    for key, value in pairs(tbl) do
        local valueType = type(value)
        if valueType == "table" then
            value = tableToJson(value)
            table.insert(result, string.format('"%s":%s', key, value))
        elseif valueType == "string" then
            table.insert(result, string.format('"%s":"%s"', key, value))
        elseif valueType == "number" then
            table.insert(result, string.format('"%s":%d', key, value))
        elseif valueType == "function" then
            table.insert(result, string.format('"%s":"%s"', key, tostring(value)))
        end
    end

    local json = "{" .. table.concat(result, ",") .. "}"
    return json
end

-- Function to check if the trade is a winner
function checkTradeWinner(trade, closingPrice)
    local winner = false
    if trade.ContractType == "Call" and closingPrice > trade.BetAmount then
        winner = true
    elseif trade.ContractType == "Put" and closingPrice < trade.BetAmount then
        winner = true
    end
    return winner
end

function sendRewards()
    for _, winner in ipairs(Winners) do
        local payout = winner.BetAmount * 1.70
        Balances[winner] = Balances[winner] + payout
        print("Transferred: " .. payout .. " successfully to " .. AOC)
    end
    -- Clear winners list after sending rewards
    Winners = {}
end

-- Trade Handler Function
Handlers.add(
    "trade",
    Handlers.utils.hasMatchingTag("Action", "trade"),
    function(m)
        if m.Tags.TradeId and m.Tags.CreatedTime and m.Tags.AssetId and m.Tags.AssetPrice and m.Tags.ContractType
            and m.Tags.ContractStatus and m.Tags.ContractExpiry and m.Tags.BetAmount then

            -- Convert BetAmount to a number
            local qty = tonumber(m.Tags.BetAmount)

            -- Check if qty is nil and handle the error
            if qty == nil then
                print("Error: BetAmount is not a valid number.")
                ao.send({ Target = m.From, Data = "Invalid BetAmount. It must be a number." })
                return
            end

            -- Validate qty is a number
            assert(type(qty) == 'number', 'Quantity Tag must be a number')

            -- Check if qty is more than 1 and less than 200000
            if qty > 1 and qty < 200000000 then
                Balances[m.From] = Balances[m.From] - qty
                print("Transferred: " .. qty .. " successfully to " .. AOC)

                -- Create trade record
                openTrades[m.Tags.TradeId] = {
                    TradeId = m.Tags.TradeId,
                    Name = m.Tags.Name,
                    AssetId = m.Tags.AssetId,
                    AssetPrice = m.Tags.AssetPrice,
                    ContractType = m.Tags.ContractType,
                    ContractStatus = m.Tags.ContractStatus,
                    CreatedTime = m.Tags.CreatedTime,
                    ContractExpiry = m.Tags.ContractExpiry,
                    BetAmount = qty
                }

                -- Print the Trades table for debugging
                print("Trades table after update: " .. tableToJson(openTrades))

                ao.send({ Target = m.From, Data = "Successfully Created Trade" })
            else
                -- Print error message for invalid quantity
                print("Invalid quantity: " .. qty .. ". Must be more than 1 and less than 200000.")
                ao.send({ Target = m.From, Data = "Invalid quantity. Must be more than 1 and less than 200000." })
            end
        else
            -- Print error message for missing tags
            print("Missing required tags for trade creation.")
            ao.send({ Target = m.From, Data = "Missing required tags for trade creation." })
        end
    end
)

-- RequestTokens Handler Function
Handlers.add(
    "RequestTokens",
    Handlers.utils.hasMatchingTag("Action", "RequestTokens"),
    function(Msg)
        local requesterAddress = Msg.From

        -- Check if the address has already requested tokens
        if RequestedAddresses[requesterAddress] then
            print("Address " .. requesterAddress .. " has already requested tokens.")
            ao.send({
                Target = requesterAddress,
                Action = "Message",
                Text = "You have already requested tokens. You cannot request again."
            })
        else
            -- Grant tokens and record the request
            local amount = 1000000
            ao.send({
                Target = AOC,
                Action = "Transfer",
                Quantity = tostring(amount),
                Recipient = requesterAddress,
            })
            print("Transferred: " .. amount .. " successfully to " .. requesterAddress)

            -- Record the address as having requested tokens
            RequestedAddresses[requesterAddress] = true

            -- Send a success message
            ao.send({
                Target = requesterAddress,
                Action = "Message",
                Text = "Tokens transferred successfully. You cannot request again."
            })
        end
    end
)

Handlers.add(
    "Trades",
    Handlers.utils.hasMatchingTag("Action", "Trades"),
    function(m)
        ao.send({ Target = m.From, Data = tableToJson(openTrades) })
    end
)

Handlers.add('getTime'
, Handlers.utils.hasMatchingTag('Action', 'getTime'), function(msg)
    currentTime = msg.Timestamp
    -- Process open trades to find expired ones
    for tradeId, trade in pairs(openTrades) do
        local contractExp = tonumber(trade.ContractExpiry)
        if currentTime > contractExp then
            fetchPrice()
            local priceMsg = { Tags = { Token = trade.AssetId } }
            getTokenPrice(priceMsg)
            trade.ClosingPrice = TOKEN_PRICES[trade.AssetId].price
            trade.ClosingTime = currentTime
            -- Check if the trade is a winner
            if checkTradeWinner(trade, trade.ClosingPrice) then
                winners[tradeId] = trade
            end
            sendRewards()
            tradeId[trade.ContractStatus] = "closed"
            expiredTrades[tradeId] = trade
            openTrades[tradeId] = nil
        end
    end
end)

Handlers.add(
    "GetTokenPrice",
    Handlers.utils.hasMatchingTag("Action", "Get-Token-Price"),
    getTokenPrice
)

Handlers.add(
    "FetchPrice",
    Handlers.utils.hasMatchingTag("Action", "Fetch-Price"),
    fetchPrice
)


