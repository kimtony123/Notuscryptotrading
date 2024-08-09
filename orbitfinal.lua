local json = require("json")
 
_0RBIT = "BaMK1dfayo75s3q1ow6AO64UDpD9SEFbeE8xYrY2fyQ"
_0RBT_TOKEN = "BUhZLMwQ6yZHguLtJYA5lLUa9LQzLXMXRfaq9FVcPJc"
 
BASE_URL = "https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=100&page=1&sparkline=false&locale=en"
FEE_AMOUNT = "1000000000000" -- 1 $0RBT

TOKEN_PRICES = TOKEN_PRICES or {}
latestPrices = latestPrices or {}

function fetchPrice()
    local url = BASE_URL

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
    latestPrices = {} -- Reset the table

    for _, asset in ipairs(res) do
        local id = asset.id
        local name = asset.name
        local symbol = asset.symbol
        local current_price = asset.current_price

        table.insert(latestPrices, {
            id = id,
            name = name,
            symbol = symbol,
            current_price = current_price
        })
    end

    print(json.encode(latestPrices)) -- Print the extracted data
end


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

Handlers.add(
    "ReceiveData",
    Handlers.utils.hasMatchingTag("Action", "Receive-Response"),
    receiveData
)