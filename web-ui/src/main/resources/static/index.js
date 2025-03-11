const notification = bootstrap.Toast.getOrCreateInstance(document.getElementById('notification'));
const error = bootstrap.Toast.getOrCreateInstance(document.getElementById('notificationError'));
const alert = bootstrap.Toast.getOrCreateInstance(document.getElementById('alert'));

const doFetch = (url, init, okMsg, errMsg) =>
    fetch(url, init).then(r => {
        const [toast, msg, msgElem] = r.status === 200 ?
            [notification, okMsg, 'notificationMessage'] : [error, errMsg, 'errorMessage'];
        document.getElementById(msgElem).innerHTML = msg;
        toast.show();
        return r;
    });

const populateFlightId = () => {
    const flight_number = document.getElementById('flightNumber').value ;
    const carrier = document.getElementById('carrier').value;
    const origin = document.getElementById('origin').value;
    const departure_timestamp = new Date(document.getElementById('departureTimestamp').value).valueOf() / 1000;
    document.getElementById('flight_id').innerHTML = `${flight_number}_${carrier}_${departure_timestamp}_${origin}`;
}

[
    document.getElementById('flightNumber'),
    document.getElementById('carrier'),
    document.getElementById('departureTimestamp'),
    document.getElementById('origin')
].forEach(e => e.addEventListener('change', populateFlightId));

const addPassengerButton = document.querySelector('.add-passenger');
const passengersContainer = document.getElementById('passengers-container');

registerFormOnChange = () =>
    document.querySelectorAll('form#flightForm input').forEach(i => {
        i.onchange = createXml;
    });

addPassengerButton.addEventListener('click', () => {
    const newPassengerRow = `
    <tr>
      <td><input type="checkbox" class="form-check-control" name="passengers[].deleted" /></td>
      <td><input type="text" class="form-control" name="passengers[].reference"></td>
      <td><input type="text" class="form-control" name="passengers[].name"></td>
      <td><input type="date" class="form-control" name="passengers[].date_of_birth"></td>
      <td><input type="text" class="form-control" name="passengers[].seat_number"></td>
      <td><input type="text" class="form-control" name="passengers[].class"></td>
      <td><button type="button" class="btn btn-danger remove-passenger">Remove</button></td>
    </tr>
  `;
    passengersContainer.insertAdjacentHTML('beforeend', newPassengerRow);
    registerFormOnChange();
});

passengersContainer.addEventListener('click', (event) => {
    if (event.target.classList.contains('remove-passenger')) {
        event.target.parentNode.parentNode.remove();
        createXml();
    }
});
const isXml = document.getElementById('isXml');
const manageIsXml = () => {
    const components = ['jsonAccordion', 'sendFlightInfoBtn']
    if(isXml.checked) {
        components.forEach(id =>
            document.getElementById(id).classList.remove('d-none')
        );
        document.getElementById('sendFlightInfoJsonBtn').classList.add('d-none');
    }
    else {
        components.forEach(id =>
            document.getElementById(id).classList.add('d-none')
        );
        document.getElementById('sendFlightInfoJsonBtn').classList.remove('d-none');
    }
}

isXml.onchange = manageIsXml;

manageIsXml();

const populatePassenger = passenger =>{
    const {reference, name, date_of_birth, seat_number,deleted} = passenger;
    const newPassengerRow = `
    <tr>
      <td><input type="checkbox" class="form-check-control" name="passengers[].deleted" value="${(!!deleted)}"/></td>
      <td><input type="text" class="form-control" name="passengers[].reference" value="${reference}"/></td>
      <td><input type="text" class="form-control" name="passengers[].name" value="${name}" /></td>
      <td><input type="date" class="form-control" name="passengers[].date_of_birth" value="${date_of_birth}"/></td>
      <td><input type="text" class="form-control" name="passengers[].seat_number" value="${seat_number}"/></td>
      <td><input type="text" class="form-control" name="passengers[].class" value="${passenger['class']}"/></td>
      <td><button type="button" class="btn btn-danger remove-passenger">Remove</button></td>
    </tr>
  `;
    passengersContainer.insertAdjacentHTML('beforeend', newPassengerRow);
    registerFormOnChange();
}

createJson = (formData, departureTimestamp, passengerRows) => {

    const flightInfo = {
        ...(function () {
            return ['flight_number', 'carrier', 'origin', 'destination'].reduce(
                (acc, e) => {
                    acc[e] = formData.get(e)
                    return acc;
                }, {'departure_timestamp': departureTimestamp})
        })(),
        passengers: Array.from(passengerRows).map(row => ({
            deleted: row.cells[0].querySelector('input').checked,
            reference: row.cells[1].querySelector('input').value,
            name: row.cells[2].querySelector('input').value,
            date_of_birth: row.cells[3].querySelector('input').value,
            seat_number: row.cells[4].querySelector('input').value,
            class: row.cells[5].querySelector('input').value
        }))
    };
    document.getElementById('xmlContent').innerHTML = JSON.stringify(flightInfo, null, 2);
}

createXml = () => {
    const formData = new FormData(flightForm);
    const departureTimestamp = new Date(formData.get('departure_timestamp')).getTime() / 1000;

    const passengerRows = document.querySelectorAll('#passengers-container tr');
    if(!isXml.checked) return createJson(
        formData, departureTimestamp, passengerRows
    );

    const xmlStr = '<flight></flight>';
    const parser = new DOMParser();
    const doc = parser.parseFromString(xmlStr, "application/xml");
    const root = doc.documentElement;

    const appendElement = n => (tag, content) => {
        const e = doc.createElement(tag);
        e.textContent = content;
        n.appendChild(e);
    }

    const appendElementRoot = appendElement(root);
    ['flight_number', 'carrier', 'origin', 'destination']
        .forEach(e => appendElementRoot(e, formData.get(e)));
    appendElementRoot('departure_timestamp', departureTimestamp);

    const passengers = doc.createElement('passengers');
    root.appendChild(passengers);

    passengerRows.forEach(row => {
        const passenger = doc.createElement('passenger');
        const appendToPassenger = appendElement(passenger);
        appendToPassenger('deleted', row.cells[0].querySelector('input').checked);
        appendToPassenger('reference', row.cells[1].querySelector('input').value);
        appendToPassenger('name', row.cells[2].querySelector('input').value);
        appendToPassenger('date_of_birth', row.cells[3].querySelector('input').value);
        appendToPassenger('seat_number', row.cells[4].querySelector('input').value);
        appendToPassenger('class', row.cells[5].querySelector('input').value);
        passengers.appendChild(passenger);
    })

    const serializer = new XMLSerializer();
    const xmlString = serializer.serializeToString(doc);

    document.getElementById('xmlContent').innerHTML = xmlFormatter(xmlString, {collapseContent: true});
}

isXml.addEventListener('change', createXml);

const timestampToFormattedDateTime = ts => new Date(ts * 1000).toISOString().slice(0, 16)
const populateForm = ({carrier, departure_timestamp, destination, flight_number, origin, passengers})=>{
    document.getElementById('flightNumber').value = flight_number;
    document.getElementById('carrier').value = carrier;
    document.getElementById('destination').value = destination;
    document.getElementById('origin').value = origin;
    document.getElementById('departureTimestamp').value = timestampToFormattedDateTime(departure_timestamp);
    populateFlightId();
    passengers.forEach(populatePassenger);
    createXml();

}


fetch('/sample')
    .then(r => r.json())
    .then(populateForm);

document.getElementById('sendFlightInfoBtn').onclick = () => {
    doFetch('/flight-information', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/xml',
            'flight_id': document.getElementById('flight_id').innerHTML
        },
        body: document.getElementById('xmlContent').value
    }, "XML send: OK" , "XML send: Error");


}
document.getElementById('sendFlightInfoJsonBtn').onclick = () =>
    doFetch('/flight-information', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'flight_id': document.getElementById('flight_id').innerHTML
        },
        body: document.getElementById('xmlContent').value
    }, "JSON send: OK" , "JSON send: Error");

let lastMessageTime=0;
const keepAliveTimeout = 10000;

const socket = new WebSocket("ws://localhost:8080/flights");
socket.onerror = (event) =>
    console.error('Received error: ', event);
socket.addEventListener("open", (event) => {
    socket.send("start");
    setInterval(
        () => {
            if (socket.readyState === WebSocket.OPEN && lastMessageTime < Date.now() - keepAliveTimeout) {
                socket.send("Keep Alive");
                lastMessageTime = Date.now();
            }
        },
        5000
    );
});

const createCell = type => content => {
    const th = document.createElement(type);
    th.innerHTML = content;
    return th
}
const createTh = createCell('th')
const createTd = createCell('td')
const addPassengerToTable = tbl =>  p => {
    const [{reference,date_of_birth, name, seat_number, deleted, clazz, passport_number}] = Object.keys(p).map((reference) => {
        return {
            reference,
            clazz:p[reference]['class'],
            ...p[reference]
        }
    });
    const existingRow = document.getElementById(reference);

    const row = (() => {
        if (existingRow) return existingRow
        else {
            const r = document.createElement('tr');
            tbl.appendChild(r);
            return r;
        }
    })();

    [...row.childNodes].forEach(n => n.remove());
    row.setAttribute('id', reference);

    row.appendChild(createTd(deleted?'<i class="bi bi-trash-fill"></i>':'&nbsp;'));
    row.appendChild(createTd(reference));
    row.appendChild(createTd(clazz));
    row.appendChild(createTd(name));
    row.appendChild(createTd(passport_number?passport_number:''));
    row.appendChild(createTd(date_of_birth));
    row.appendChild(createTd(seat_number));

}

const updateCount = id => {
    const span = document.getElementById(id);
    const count = Number(span.innerHTML);
    span.innerHTML = count + 1;
}

const updateJsonFlightInformation = fi => {
    document.getElementById('jsonFi').innerHTML = fi;
}
const updateRequiredMeals = ({biz, first, eco, prem}) => {
    document.getElementById('reqEco').innerHTML = eco;
    document.getElementById('reqPrem').innerHTML = prem;
    document.getElementById('reqBiz').innerHTML = biz;
    document.getElementById('reqFirst').innerHTML = first;
}

const showAlert = ({type}) => {
    document.getElementById('alertMessage').innerHTML = type;
    alert.show();
}

socket.onmessage = (event) => {
    lastMessageTime = Date.now();
    const {data} = event;
    const [y] = data;
    if(y === 'Y') return;
    const {passenger, flight_information, request, response, required_meals, alerts} = JSON.parse(data);
    if(passenger) addPassengerToTable(document.getElementById('flightTbl'))(passenger);
    if(flight_information) updateJsonFlightInformation(JSON.stringify(flight_information));
    if(request) updateCount('requests');
    if(response) updateCount('responses');
    if(required_meals) updateRequiredMeals(Object.values(required_meals)[0]);
    if(alerts) showAlert(Object.values(alerts)[0])
};

document.getElementById('checkinBtn').onclick = () => {
    doFetch('/check-in-open', {
        method: 'POST',
        headers: {
            'flight_id': document.getElementById('flight_id').innerHTML
        }
    }, 'Check in open sent', 'Check in open error');
}

document.getElementById('sendCmsBtn').onclick = () => {
    doFetch('/cms-event', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'flight_id': document.getElementById('flight_id').innerHTML
        },
        body: JSON.stringify({
            business_meals: document.getElementById('business_meals').value,
            economy_meals: document.getElementById('economy_meals').value,
            first_meals: document.getElementById('first_meals').value,
            premium_meals: document.getElementById('premium_meals').value
        })


    }, 'Send CMS Event OK', 'Send CMS Event error');
}

