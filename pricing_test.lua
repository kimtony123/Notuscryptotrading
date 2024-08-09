-- Time Decay Function
local function timeDecay(expiryMinutes)
    local decayFactor = math.exp(-expiryMinutes / 525600)
    return math.max(decayFactor, 0.01) -- Ensure a minimum decay factor to prevent infinity payoff
end

-- Adjust Probability Function
local function adjustProbability(prob, betAmount, spread, expiryMinutes)
    spread = spread or 0
    expiryMinutes = expiryMinutes or 0

    -- Apply a nonlinear transformation (e.g., exponential) to adjust probability
    local adjustedProb = math.exp(prob / 100) / math.exp(1)

    -- Apply time decay
    local decayFactor = timeDecay(expiryMinutes)
    local timeAdjustedProb = adjustedProb * decayFactor

    local betAdjustmentFactor = 1 + betAmount / 10000000
    local finalAdjustedProb = timeAdjustedProb / betAdjustmentFactor

    return finalAdjustedProb * (1 + spread)
end

-- Function to calculate payoffs
local function calculatePayoffs(response, betAmountCall, betAmountPut, expiryDayCall, expiryDayPut, balance)
    if not response then
        print("Response data is missing.")
        return
    end

    local sentimentVotesDownPercentage = response.sentiment_votes_down_percentage
    local sentimentVotesUpPercentage = response.sentiment_votes_up_percentage
    local expiryMinutesCall = expiryDayCall
    local expiryMinutesPut = expiryDayPut

    -- Determine which side has the higher probability
    local isDownHigher = sentimentVotesDownPercentage > sentimentVotesUpPercentage

    -- Define the spread based on balance
    local totalSpread = math.exp(-balance / 1000000) -- Exponential function to determine spread

    -- Apply the spread split
    local lowerSpread = (2 / 3) * totalSpread
    local higherSpread = (1 / 3) * totalSpread

    local adjustedDownProbability = adjustProbability(
        sentimentVotesDownPercentage,
        betAmountPut,
        isDownHigher and higherSpread or lowerSpread,
        expiryMinutesPut
    )
    local adjustedUpProbability = adjustProbability(
        sentimentVotesUpPercentage,
        betAmountCall,
        isDownHigher and lowerSpread or higherSpread,
        expiryMinutesCall
    )

    -- Normalize the probabilities to ensure they sum to 1
    local totalAdjustedProbability = adjustedDownProbability + adjustedUpProbability
    local normalizedDownProbability = adjustedDownProbability / totalAdjustedProbability
    local normalizedUpProbability = adjustedUpProbability / totalAdjustedProbability

    -- Calculate the odds
    local oddsDown = string.format("%.3f", 1 / normalizedDownProbability)
    local oddsUp = string.format("%.3f", 1 / normalizedUpProbability)

    return oddsDown, oddsUp
end

-- Example usage
local response = {
    sentiment_votes_down_percentage = 55,
    sentiment_votes_up_percentage = 45
}

local betAmountCall = 100
local betAmountPut = 100
local expiryDayCall = 30
local expiryDayPut = 30
local balance = 500000 -- Example balance

local oddsDown, oddsUp = calculatePayoffs(response, betAmountCall, betAmountPut, expiryDayCall, expiryDayPut, balance)
print("Odds Down:", oddsDown)
print("Odds Up:", oddsUp)
