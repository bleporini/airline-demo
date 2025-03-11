function generateRandomPassportNumber() {
    // Define the characters that can be in the passport number
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const numbers = '0123456789';

    // Generate two random letters
    let passportNumber = '';
    for (let i = 0; i < 2; i++) {
        passportNumber += letters.charAt(Math.floor(Math.random() * letters.length));
    }

    // Generate seven random digits
    for (let i = 0; i < 7; i++) {
        passportNumber += numbers.charAt(Math.floor(Math.random() * numbers.length));
    }

    return passportNumber;
}


export const handler = async (event, context) => {

    const queryParameters = event.queryStringParameters;
    const {body,requestContext:{domainName, http:{path,method}}}=event;

    if(method === 'POST' && path === '/passport'){
        try{
            return {
                statusCode: 200,
                body: {
                    ...(JSON.parse(body)),
                    passport_number: generateRandomPassportNumber()
                }
            };
        }catch (e) {
            return {
                statusCode: 400,
                body: {
                    error : e.toString(),
                    event,
                    context
                }
            }

        }
    }
    if (!queryParameters)
        return {
            statusCode: 404,
            body: JSON.stringify({event, context})
        };

    if (queryParameters.subscribers)
        return {
            statusCode: 200,
            body: JSON.stringify([`https://${domainName}?reference=1`, `https://${domainName}?reference=2`])
        }


    if (queryParameters && queryParameters.reference) {

        return {
            statusCode: 200,
            body: JSON.stringify({reference: queryParameters.reference, passport_number: generateRandomPassportNumber()})
        };
    }
    return {
        statusCode: 404,
        body: 'Passenger not found'
    };
}


