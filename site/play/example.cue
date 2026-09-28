// ---- schema.cue ------------------------------------------------
#Currency: "EUR" | "USD" | "CHF"

#Account: {
	iban:     =~"^[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}$"
	currency: #Currency
	balance:  int & >=0
}

#Transfer: {
	from: #Account
	to: #Account & {currency: from.currency}
	amount: int & >0 & <=from.balance
	fee:    *0 | int & >=0
}

transfers: [...#Transfer]

// ---- policy.cue: added by another team, refines, never overrides
#Transfer: {
	amount: <=10_000
	if amount > 5_000 {fee: 15}
}

// ---- data ------------------------------------------------------
transfers: [{
	from: {iban: "FR7630006000011", currency: "EUR", balance: 8000}
	to: {iban: "DE8937040044053", currency: "EUR", balance: 0}
	amount: 6000
}, {
	from: {iban: "FR7630006000011", currency: "EUR", balance: 300}
	to: {iban: "CH9300762011623", currency: "CHF", balance: 0}
	amount: 500
}]
