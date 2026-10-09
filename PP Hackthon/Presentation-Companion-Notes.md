# Smart Safety Ecosystem: Presentation Companion

Title: **Smart Safety Ecosystem: LoRa-Based Accident Alert and Portable Wearable Risk Screening System**
Subtitle: *An IoT-Enabled Approach to Road Safety, Emergency Response, and Preliminary Field Screening*

## Items to confirm before presenting

- The source documents were not attached to the chat, so slide content follows the component names, algorithm name, score bands (0-39, 40-79, 80 or above) and subsystem functions given in the brief. Check every slide against your two documents.
- Vehicle impact and rollover thresholds are **not** shown, because no values were available. Add the source's example thresholds (as preliminary calibration values) on slide 10 if you wish.
- The AWTRA worked example on slide 11 uses **illustrative numbers** (55 and 0). Replace them with the real weights and bands from your wristband document.
- "Existing" in the status legend means *specified in the source documents*. Change it to "implemented and tested" only where that is true.
- No test results are shown. All result fields say "To be tested".

---

## Part 1. Slide-by-slide outline with speaker notes

### Slide 1: Smart Safety Ecosystem

**Slide content**
- Smart Safety Ecosystem: LoRa-Based Accident Alert and Portable Wearable Risk Screening System
- An IoT-Enabled Approach to Road Safety, Emergency Response, and Preliminary Field Screening
- Team, department, institution, guide and academic year (editable placeholders)

**Recommended visual:** Connected vehicle, LoRa gateway, cloud backend, responders and a standalone wristband drawn with editable shapes.

**Speaker notes:** Good morning everyone. Our project is the Smart Safety Ecosystem. It brings together two safety functions: a LoRa-based accident alert module for vehicles, where LoRa stands for Long Range radio, and a portable wristband for preliminary alcohol-exposure and temperature screening. The two subsystems work independently, and an optional shared platform can show their events side by side. IoT, the Internet of Things, simply means these small devices can send data to software that others can use. Today I will explain what exists in our source designs, what we propose to add, and what still has to be validated.

**Transition:** Let me first show how the next few minutes are organised.

### Slide 2: Agenda

**Slide content**
- 1 Introduction
- 2 Problem statement
- 3 Proposed solution
- 4 Objectives
- 5 System architecture
- 6 Hardware and software
- 7 Working methodology
- 8 Algorithm and alert logic
- 9 Real-world applications
- 10 Benefits, limitations, and validation
- 11 Future scope
- 12 Conclusion

**Recommended visual:** Two-column numbered agenda with a WHAT / WHY / WHERE / WHEN / HOW strip.

**Speaker notes:** This is the roadmap. We begin with the introduction and the problem, then the proposed solution and objectives. After that comes the architecture, the hardware and software, and the working methodology, including the accident-detection flow and the wristband algorithm. We close with applications, benefits, limitations and validation, future scope and the conclusion. Along the way the talk answers five questions: what the system is, why it matters, where it can be used, when each part activates, and how it works.

**Transition:** We start with the problem that motivates the project.

### Slide 3: Problem statement

**Slide content**
- Problem A: Delayed accident response
- Problem B: Limited portable preliminary screening
- Problem C: Disconnected safety information
- Need for a portable, modular, cost-conscious system with separate detection methods

**Recommended visual:** Three problem cards in the layout style of the NDPS reference slide, a caution strip, and a one-sentence problem statement.

**Speaker notes:** Three problems motivate this work. First, accident information and precise location may reach responders late, especially where conventional reporting is slow or communication is unreliable. Second, laboratory-based substance screening involves sample handling, specialist equipment, transport and time. Portable tools may support preliminary field assessment, but the right method depends on the substance and the sample. Third, accident alerts and wearable screening normally work separately, so authorized staff see them in different places. I want to be clear about one point from the reference problem statement on NDPS, the Narcotic Drugs and Psychotropic Substances Act. Our wristband screens for alcohol exposure and monitors temperature. It does not identify narcotic or psychotropic substances. That would need a separately validated sensing method, suitable samples and confirmatory testing where the law requires it.

**Transition:** With the problem defined, here is how our unified solution responds to it.

### Slide 4: Proposed unified solution

**Slide content**
- Vehicle accident detection and LoRa emergency alert
- Wearable alcohol-exposure and temperature screening
- Shared monitoring, logging, and notification platform (proposed)

**Recommended visual:** Three labelled blocks: vehicle subsystem, shared platform in the centre, wearable subsystem, with data arrows into the platform.

**Speaker notes:** The solution has three elements. On the left is the vehicle subsystem, which detects a possible collision or rollover and sends a compact alert over LoRa. On the right is the wearable subsystem, which screens for alcohol exposure and measures non-contact temperature, and classifies the result locally on the wristband. In the middle is a shared monitoring platform that logs events and notifies authorized people. For each block I have separated what already exists in the source designs from what must still be developed for integration. The platform and the optional wristband link are proposals, not finished work. The key design principle is that the two detection methods stay separate, and an alcohol reading never implies that a driver caused an accident.

**Transition:** Next, the specific objectives and the boundaries of our scope.

### Slide 5: Objectives and scope

**Slide content**
- Detect potential vehicle collisions and rollovers
- Report location through a LoRa gateway architecture
- Provide portable preliminary wearable screening
- Apply lightweight on-device risk classification
- Present separate event categories in one interface
- Reduce avoidable false alerts with validation logic
- Protect sensitive data and state technical limitations

**Recommended visual:** Seven numbered objectives with a scope card listing what is claimed and what is not.

**Speaker notes:** These are the seven objectives. They cover collision and rollover detection, reporting location through a gateway-based architecture, portable preliminary screening, lightweight local classification, a common interface with separate event categories, fewer false alerts through confirmation and cancellation logic, and protection of sensitive data. The scope card on the right is equally important. We do not claim to identify specific narcotics, diagnose intoxication or fever, prove the cause of an accident, or reach a hospital without gateway and routing infrastructure.

**Transition:** Now let us look at what the system is made of, starting with the components.

### Slide 6: WHAT: Components and technologies

**Slide content**
- Vehicle subsystem: IMU, GPS, microcontroller, LoRa transceiver, optional GSM, gateway, backend
- Wearable subsystem: Arduino Nano, MQ-3, MLX90614, SSD1306 OLED, buzzer, LEDs, battery
- Shared platform: dashboard, event database, access controls, notification interfaces
- Legend: existing, optional, proposed, future

**Recommended visual:** Two side-by-side component cards, a shared-platform bar and a status legend.

**Speaker notes:** This slide answers WHAT. The vehicle subsystem uses an accelerometer and gyroscope, a GPS receiver, a microcontroller and a LoRa transceiver, with an optional GSM module as a fallback. A LoRa gateway and a backend server receive the packet. Facility lookup and notifications are proposed additions. The wearable uses an Arduino Nano, an MQ-3 alcohol sensor, an MLX90614 non-contact infrared temperature sensor, an SSD1306 OLED display, a buzzer, red, yellow and green LEDs, and a battery. The shared platform is entirely proposed. The legend shows how to read the status of each block: solid means specified in our source documents, dashed amber means optional, dashed teal means proposed, and dotted grey means future scope.

**Transition:** Why do these components matter? That brings us to the motivation and benefits.

### Slide 7: WHY: Motivation and benefits

**Slide content**
- Earlier notification
- GPS-based incident reporting
- Portable preliminary screening
- Local processing
- Modular integration
- Anticipated benefits vs measured results

**Recommended visual:** Five benefit rows and an anticipated-versus-measured comparison card.

**Speaker notes:** This slide answers WHY. Earlier notification matters because an automatic alert reduces dependence on someone manually reporting the crash. GPS coordinates and a timestamp travel with every alert, so responders know where to look. The wristband gives a quick, portable, preliminary indication on site, and because classification runs on the microcontroller it works without cloud connectivity. Modularity means each subsystem works alone and the shared platform is optional. I must stress that these are anticipated benefits from the design. No measured response-time improvement or detection accuracy is reported in our source documents, so we show those fields as to be tested. Also, an alcohol screening reading is not equivalent to confirmed intoxication.

**Transition:** Next, where the system can be used and when each part activates.

### Slide 8: WHERE and WHEN: Deployment and activation

**Slide content**
- Six proposed deployment settings
- Vehicle subsystem activation sequence
- Wearable measurement sequence
- Requirements: gateway coverage, backhaul, suitable sensing environment

**Recommended visual:** Scenario grid of deployment settings and two activation timelines.

**Speaker notes:** This slide answers WHERE and WHEN. Where: roadways and highways, campuses, fleet operations, industrial workplaces, authorized field-screening environments, and emergency-response networks. All of these are proposed deployments, not tested installations. When: the vehicle subsystem monitors motion continuously. When a threshold is exceeded, it enters a confirmation window, then a manual cancellation period. If the alert is not cancelled, it acquires a GPS fix and transmits a LoRa packet. The wearable runs a periodic measurement cycle: read the sensors, filter with a moving average, compute the AWTRA risk score, and show the status on the OLED, LEDs and buzzer. Two limits apply. LoRa needs suitable gateway coverage and an internet connection at the gateway. Wearable screening needs an appropriate sensing environment, for example sensor warm-up, calibration and limited airflow or gas interference.

**Transition:** Now the core technical view: the system architecture.

### Slide 9: Main system architecture

**Slide content**
- Vehicle: motion sensors, microcontroller, confirmation and cancellation, GPS, LoRa, gateway
- Wearable: MQ-3 and MLX90614, Arduino Nano, filter, AWTRA, local outputs, optional link
- Shared platform: backend, facility lookup, notifications, event database and dashboard
- Real-world notes: coverage, authentication, secure communication, failure handling

**Recommended visual:** Three-zone architecture drawn with editable shapes; arrow colours separate sensor data, LoRa, internet backhaul and emergency notification.

**Speaker notes:** This is the main architecture. The top lane is the vehicle subsystem. Motion sensors feed the microcontroller, which applies the confirmation and manual cancellation logic, then reads the GPS and sends a compact packet over LoRa to the gateway. The gateway forwards it over the internet to the backend. The important point is that LoRa itself never contacts a hospital. The gateway and backend do the routing: the backend identifies nearby hospitals and fire-rescue facilities and sends notifications. The lower lane is the wearable. The MQ-3 and MLX90614 feed the Arduino Nano, which filters the readings, applies the AWTRA rules, and drives the OLED, LEDs and buzzer. This works entirely on its own. The dashed link to the platform is optional and proposed, and would carry only authorized records. The right-hand column is the shared platform with separate event records. All dashed teal blocks are proposed, not implemented. For a real deployment we would add multiple gateways for coverage, device authentication and encrypted payloads, database maintenance, retry and queueing, and a GSM fallback where available.

**Transition:** Let us now walk through the accident-detection workflow step by step.

### Slide 10: HOW: Accident detection workflow

**Slide content**
- Start, read motion data, detect potential impact or rollover, confirm event, activate warning
- Start cancellation window, cancel or continue, acquire GPS fix, construct packet, transmit via LoRa
- Gateway forwards, backend identifies nearby facilities, notification sent (proposed)
- Alternate paths: no GPS, no gateway coverage, optional GSM, manual cancel

**Recommended visual:** Three-row snake flowchart with decision diamonds and an alternate-path panel.

**Speaker notes:** Here is the accident workflow. The device starts by reading accelerometer and gyroscope data continuously. When the motion pattern suggests a possible impact or rollover, it checks the event against calibrated thresholds over a short confirmation window. If it is confirmed, the device activates a warning and starts a manual cancellation window, so a harmless bump can be cancelled. If nobody cancels, it acquires a GPS fix with a timestamp, builds a compact packet, and transmits it over LoRa. The gateway forwards the packet to the backend, which identifies nearby hospitals and fire-rescue facilities and sends notifications. That last step is a proposed deployment. The panel at the lower right shows alternate paths: if there is no GPS fix we send a flagged packet, with the last known position if available. If there is no gateway coverage, the device retries, and a GSM fallback can be used where implemented. The thresholds in the source are preliminary calibration values, not universal crash-detection standards, and must be calibrated for each vehicle.

**Transition:** Now the second subsystem: the wearable screening flow and the AWTRA algorithm.

### Slide 11: HOW: Wearable screening and AWTRA algorithm

**Slide content**
- Sensor acquisition, moving-average filtering, temperature and alcohol evaluation, weighted risk score, status, local alert
- Documented bands: 0 to 39 Safe, 40 to 79 Medium risk, 80 or above High risk
- Prototype rules; require calibration and validation
- Illustrative worked example

**Recommended visual:** Six-step pipeline, three score-band cards, an illustrative scoring example and a limitations card.

**Speaker notes:** This is the wearable pipeline. The Arduino Nano reads the MQ-3 alcohol sensor and the MLX90614 non-contact temperature sensor. A moving average smooths noisy readings. The AWTRA, the Adaptive Weighted Threshold Risk Algorithm, evaluates the filtered values: it classifies temperature, evaluates the alcohol-sensor reading, and combines them into a weighted risk score. The documented bands are 0 to 39 Safe, 40 to 79 Medium risk, and 80 or above High risk. The OLED shows the status and the LEDs and buzzer give a local alert. This is rule-based threshold logic running on a microcontroller. It is not a trained machine-learning or deep-learning model. The worked example on the slide uses illustrative numbers only, to show how contributions add up, and they are not measured data. These are prototype rules. They need sensor calibration and validation, and they are not clinically validated thresholds. Temperature from the MLX90614 is not a diagnosis of fever or intoxication, and the MQ-3 can respond to other gases besides alcohol vapour.

**Transition:** Next, the hardware, software and data flow in one table.

### Slide 12: Hardware, software, and data flow

**Slide content**
- Component table with purpose, subsystem and implementation status
- Tools: Arduino IDE, Embedded C/C++, TinyGPS++, LoRa library, sensor and display libraries, backend and database stack

**Recommended visual:** Compact 14-row table with colour-coded status and a software strip.

**Speaker notes:** This table summarises every component with its purpose, its subsystem and its implementation status. Existing means the item is specified in our source documents. Optional covers the GSM fallback. Proposed covers the backend stack, the dashboard and notifications, which would be built for integration. For software we use the Arduino IDE and Embedded C and C++. TinyGPS++ parses the GPS data, and we use a LoRa library for the radio and the standard libraries for the MLX90614 and the SSD1306 display. The backend and database stack is a design choice still to be made, and I am not claiming specific component specifications or costs here. In terms of data flow, the vehicle sends a compact packet over LoRa through the gateway to the backend, while the wearable classifies locally and may send an authorized record in an extended version.

**Transition:** With the design explained, here is where it could be applied.

### Slide 13: Real-world applications and deployment

**Slide content**
- Fleet and road-safety monitoring
- Campus and industrial vehicle safety
- Emergency-response coordination
- Authorized workplace safety programs
- Preliminary screening research
- Connected wearable monitoring
- Limitations: coverage, calibration, interference, power, false positives, privacy, regulation

**Recommended visual:** Six application cards with status lines and a limitations strip.

**Speaker notes:** These are the application areas we see. Fleet and road-safety monitoring would use the vehicle module with gateways along routes. Campus and industrial vehicle safety suits a site with one or two gateways. Emergency-response coordination depends on an agreed integration with responders. Authorized workplace safety programs and preliminary screening research could use the wristband, with consent. Connected wearable monitoring covers the optional link to the platform. For every card, the status is a plausible future deployment. None has been tested as an installation. The strip at the bottom lists realistic limitations: gateway coverage, sensor calibration, environmental interference, power management, false positives, privacy, and regulatory approval. Any use that affects people, such as screening in a workplace, needs appropriate consent, policy and approval.

**Transition:** That brings us to how we would test and validate the system, and its limitations.

### Slide 14: Testing, validation, and limitations

**Slide content**
- Ten-row test matrix with results marked To be tested
- Emergency use requires safety validation
- Substance screening requires validated methods and confirmatory testing

**Recommended visual:** Test matrix table and a caution strip.

**Speaker notes:** This is our validation plan. The source documents do not report measured results, so every result field says To be tested, and we are deliberately not showing any invented accuracy figures. We plan to test controlled impact detection, GPS acquisition and location accuracy, LoRa packet reception and loss, gateway-to-backend delivery, nearest-facility lookup, false triggers and manual cancellation, wearable sensor repeatability, AWTRA classification consistency, battery endurance, and data access and communication security. Two cautions: emergency use requires appropriate safety validation before anyone relies on it, and any substance screening requires validated methods, with confirmatory testing where legally required. A preliminary positive result is never proof.

**Transition:** Finally, how the project could grow: the future scope.

### Slide 15: Future scope

**Slide content**
- Near term: multiple gateways, secure device authentication, wearable sensor validation
- Mid term: emergency-service integration, mobile app and unified dashboard, privacy-preserving storage
- Longer term: expanded field trials, independently validated substance-specific screening

**Recommended visual:** Three roadmap columns with eight items.

**Speaker notes:** Our future scope has eight items, grouped in an indicative order. First, planning coverage with multiple LoRa gateways, adding secure device authentication and payload protection, and validating the wearable sensors more thoroughly. Next, more reliable emergency-service integration, a mobile application and unified dashboard, and privacy-preserving event storage with access auditing. Over the longer term, we want expanded field trials and performance evaluation, and, only if independently validated, additional substance-specific screening technologies. This last point addresses the NDPS problem honestly: it needs a different validated sensing method, not a reinterpretation of the current sensors.

**Transition:** Let me close with the conclusion.

### Slide 16: Conclusion

**Slide content**
- Two complementary safety functions, one modular approach
- Gateway and backend provide emergency routing; LoRa alone does not
- The wristband classifies locally with rule-based AWTRA
- Real deployment depends on validation, reliable communication, appropriate screening technology, security, and regulatory compliance
- Thank You. Questions are welcome.

**Recommended visual:** Four conclusion points and a Thank You card.

**Speaker notes:** To conclude: the Smart Safety Ecosystem combines two complementary safety functions through a modular monitoring approach. One is location-based accident alerting. The other is portable preliminary wearable screening. The gateway and backend make emergency routing possible, because LoRa on its own does not contact a hospital. The wearable uses a separate local classification process, and an alcohol reading never proves that a driver caused an accident. Real-world deployment depends on validation, reliable communication, appropriate screening technology, security, and regulatory compliance. Thank you. I would be happy to take your questions.

**Transition:** Thank you. Questions, please.

---

## Part 2. Architecture description (slide 9; also exported as System-Architecture-Diagram.png)

- **Vehicle subsystem:** accelerometer and gyroscope, then microcontroller, then confirmation and manual cancellation, then GPS fix and timestamp, then LoRa transceiver, then (LoRa radio link) LoRa gateway.
- **Wearable subsystem (standalone):** MQ-3 and MLX90614, then Arduino Nano, then moving-average filter, then AWTRA rule-based classification, then OLED, LEDs and buzzer. An optional authorized link to the platform is proposed.
- **Shared platform (proposed):** backend service, nearest-facility lookup, authorized notifications, and an event database and dashboard with separate records for accident and screening events.
- **Response (proposed):** hospital and fire-rescue contact, and authorized monitoring staff.
- **Arrow types:** navy = sensor data, teal dashed = LoRa radio, grey = internet backhaul, red = emergency notification, dashed teal boxes = proposed and not implemented.
- **Deployment notes:** plan gateway coverage with multiple gateways and retries; use device authentication, encrypted payloads and role-based access; handle failures (no GPS gives a flagged packet, no LoRa uses optional GSM, backend outage uses queue and retry).

---

## Part 3. Opening script (about 60 seconds)

Good morning, respected faculty and guests. We are presenting the Smart Safety Ecosystem, an IoT-enabled approach to road safety, emergency response and preliminary field screening.

The project combines two complementary safety functions. The first is a LoRa-based accident alert module. It detects a possible collision or rollover, gives the driver a short chance to cancel a false alarm, captures the GPS position, and sends a compact alert through a gateway to a backend that can find nearby hospitals and fire-rescue services. The second is a portable wristband that screens for alcohol exposure and monitors temperature, and classifies the result locally using a rule-based algorithm called AWTRA.

The two subsystems stay independent, and an optional shared platform can show their events in one place. In the next few minutes we will explain what each part does, why it matters, where and when it activates, and how it works. We will also be clear about what is already specified in our designs, what we propose to add, and what still has to be validated.

---

## Part 4. Conclusion script (about 45 seconds)

To conclude, the Smart Safety Ecosystem combines two complementary safety functions through a modular monitoring approach: location-based accident alerting and portable preliminary wearable screening.

The gateway and backend are what make emergency routing possible, because LoRa on its own does not contact a hospital. The wristband uses a separate local classification process, and an alcohol reading never proves that a driver caused an accident.

Real-world deployment depends on proper validation, reliable communication, appropriate screening technology, strong security and privacy, and regulatory compliance. Thank you. We would be happy to answer your questions.

---

## Part 5. Likely viva questions and answers

**1. Does LoRa send the alert directly to a hospital?**
No. LoRa is only the radio link between the vehicle node and a LoRa gateway. The gateway forwards the packet over the internet to a backend, which identifies nearby hospitals and fire-rescue facilities from the GPS position and sends notifications through SMS, app or dispatch integrations. These routing and notification steps are proposed for deployment.

**2. Why LoRa instead of Wi-Fi or only GSM?**
LoRa offers long range at low power for small packets, which suits a compact emergency message, and it does not need a cellular subscription at the vehicle node. Its limit is that it needs gateway coverage. That is why a GSM fallback is listed as optional where it is available.

**3. How do you reduce false alerts?**
The event must exceed calibrated thresholds, be confirmed over a confirmation window, and then pass a manual cancellation period before any packet is sent. The thresholds are preliminary values and must be calibrated for each vehicle.

**4. What if there is no GPS fix or no gateway in range?**
With no GPS fix the device sends a flagged packet, using the last known position if available. With no gateway coverage it retries, and an optional GSM fallback can be used where implemented. A backend outage is handled by queueing and retrying.

**5. What does AWTRA stand for and how does it work?**
Adaptive Weighted Threshold Risk Algorithm. It filters sensor readings with a moving average, evaluates the alcohol-sensor and temperature readings against thresholds, combines them into a weighted risk score, and maps the score to a status band: 0 to 39 Safe, 40 to 79 Medium risk, 80 or above High risk.

**6. Is AWTRA machine learning?**
No. It is rule-based, threshold-driven logic that runs on the Arduino Nano. It is not a trained machine-learning or deep-learning model.

**7. Can the wristband detect drugs, as in the NDPS problem statement?**
No. The MQ-3 responds to alcohol vapour and the MLX90614 measures temperature. Neither can identify narcotic or psychotropic substances. Screening for specific substances needs a separately validated sensing method, suitable samples, and confirmatory laboratory or forensic testing where the law requires it. We list this under future scope, only if independently validated.

**8. Does a high reading mean the person is intoxicated?**
No. It is a preliminary screening indication. The MQ-3 can also respond to other gases, and readings depend on calibration and environment. Confirmed intoxication needs validated, legally accepted testing.

**9. Does the temperature reading diagnose fever?**
No. The MLX90614 measures non-contact infrared temperature. Readings are affected by distance, ambient conditions and skin or surface state, so they are an indication to monitor, not a diagnosis.

**10. Does an alcohol reading mean the driver caused an accident?**
No. The two subsystems detect different things and are kept separate. The platform stores them as separate event categories, and no causal link is implied.

**11. What accuracy and response time did you achieve?**
We do not report any measured accuracy or response-time figures, because they have not been established. The test matrix on slide 14 lists the planned tests, and all results are marked To be tested.

**12. How do you protect privacy and sensitive data?**
Screening should only be done with consent and authorization. We propose device authentication, encrypted payloads, role-based access control, minimal retention, and access auditing. Wearable classification works locally without cloud connectivity.

**13. What is implemented and what is only proposed?**
Components specified in the source documents are marked Existing. The optional GSM module is marked Optional. The shared platform, facility lookup, notifications and the optional wristband link are marked Proposed, and further screening technologies are Future scope.

**14. What are the main limitations?**
Gateway coverage, sensor calibration, environmental interference, power management, false positives, privacy, and regulatory approval.

**15. How would you scale this up?**
Plan multiple gateways with overlapping coverage, add device authentication and payload protection, maintain the database with retention and audit rules, build a mobile app and unified dashboard, and run expanded field trials before any real emergency or screening use.
