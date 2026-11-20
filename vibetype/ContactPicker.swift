import Contacts
import ContactsUI
import UIKit

// MARK: - Contact Picker Handlers
extension ViewController: CNContactPickerDelegate {

    func handleContactPick() {
        let picker = CNContactPickerViewController()
        picker.delegate = self
        picker.displayedPropertyKeys = [CNContactEmailAddressesKey, CNContactPhoneNumbersKey]
        present(picker, animated: true)
    }

    func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
        let picked = contacts.map { contact in
            PickedContact(
                emailAddresses: contact.emailAddresses.map { $0.value as String },
                familyName: contact.familyName,
                givenName: contact.givenName,
                phoneNumbers: contact.phoneNumbers.map { $0.value.stringValue }
            )
        }
        guard let data = try? JSONEncoder().encode(picked),
              let json = String(data: data, encoding: .utf8) else {
            dispatchEvent(eventName: "contact-pick-error", detail: "The selected contacts could not be encoded.")
            return
        }
        dispatchEvent(eventName: "contact-pick-result", detail: json)
    }

    func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
        dispatchEvent(eventName: "contact-pick-cancel", detail: "")
    }
}

struct PickedContact: Encodable {
    let emailAddresses: [String]
    let familyName: String
    let givenName: String
    let phoneNumbers: [String]
}
