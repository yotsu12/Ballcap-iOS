//
//  DataRepresentable.swift
//  Ballcap
//
//  Created by 1amageek on 2019/04/05.
//  Copyright © 2019 Stamp Inc. All rights reserved.
//

import FirebaseFirestore

public protocol DataRepresentable: class {

    associatedtype Model: Modelable & Codable

    var data: Model? { get set }
}

public extension DataRepresentable where Self: Document {

    init() {
        self.init(documentReference: Document.collectionReference.document())
        self.data = Model()
    }

    init(collectionReference: CollectionReference? = nil) {
        let collectionReference: CollectionReference = collectionReference ?? Document.collectionReference
        self.init(documentReference: collectionReference.document())
        self.data = Model()
    }

    init(id: String, collectionReference: CollectionReference? = nil) {
        let collectionReference: CollectionReference = collectionReference ?? Document.collectionReference
        self.init(documentReference: collectionReference.document(id))
        self.data = Model()
    }

    init?(id: String, from data: [String: Any], collectionReference: CollectionReference? = nil) {
        let collectionReference: CollectionReference = collectionReference ?? Document.collectionReference
        self.init(documentReference: collectionReference.document(id))
        do {
            self.data = try Firestore.Decoder().decode(Model.self, from: data)
            self.createdAt = data["createdAt"] as? Timestamp ?? Timestamp(date: Date())
            self.updatedAt = data["updatedAt"] as? Timestamp ?? Timestamp(date: Date())
        } catch (let error) {
            print(error)
            return nil
        }
    }

    init?(snapshot: DocumentSnapshot) {
        self.init(documentReference: snapshot.reference)
        self.snapshot = snapshot
        guard let data: [String: Any] = snapshot.data() else {
            self.snapshot = snapshot
            return
        }
        do {
            self.data = try Firestore.Decoder().decode(Model.self, from: data)
            self.createdAt = data["createdAt"] as? Timestamp ?? Timestamp(date: Date())
            self.updatedAt = data["updatedAt"] as? Timestamp ?? Timestamp(date: Date())
        } catch (let error) {
            print(error)
            return nil
        }
    }
}

public extension DataRepresentable where Self: Document {

    func save(reference: DocumentReference? = nil, completion: ((Error?) -> Void)? = nil) {
        let batch: Batch = Batch()
        batch.save(document: self)
        batch.commit(completion)
    }

    func update(reference: DocumentReference? = nil, completion: ((Error?) -> Void)? = nil) {
        let batch: Batch = Batch()
        batch.update(document: self)
        batch.commit(completion)
    }

    func delete(reference: DocumentReference? = nil, completion: ((Error?) -> Void)? = nil) {
        let batch: Batch = Batch()
        batch.delete(document: self)
        batch.commit(completion)
    }
}

// MARK: -

public extension DataRepresentable where Self: Document {

    static func get(documentReference: DocumentReference, cachePolicy: CachePolicy = .default, completion: @escaping ((Self?, Error?) -> Void)) {
        switch cachePolicy {
        case .default:
            if let document: Self = self.get(documentReference: documentReference) {
                completion(document, nil)
            }
            documentReference.getDocument { (snapshot, error) in
                if let error = error {
                    completion(nil, error)
                    return
                }
                guard let snapshot = snapshot, snapshot.exists else {
                    completion(nil, DocumentError.invalidData)
                    return
                }
                guard let document: Self = Self(snapshot: snapshot) else {
                    completion(nil, DocumentError.invalidData)
                    return
                }
                completion(document, nil)
            }
        case .cacheOnly:
            if let document: Self = self.get(documentReference: documentReference) {
                completion(document, nil)
            }
            documentReference.getDocument(source: FirestoreSource.cache) { (snapshot, error) in
                if let error = error {
                    completion(nil, error)
                    return
                }
                guard let snapshot = snapshot, snapshot.exists else {
                    completion(nil, DocumentError.invalidData)
                    return
                }
                guard let document: Self = Self(snapshot: snapshot) else {
                    completion(nil, DocumentError.invalidData)
                    return
                }
                completion(document, nil)
            }
        case .networkOnly:
            documentReference.getDocument(source: FirestoreSource.server) { (snapshot, error) in
                if let error = error {
                    completion(nil, error)
                    return
                }
                guard let snapshot = snapshot, snapshot.exists else {
                    completion(nil, DocumentError.invalidData)
                    return
                }
                guard let document: Self = Self(snapshot: snapshot) else {
                    completion(nil, DocumentError.invalidData)
                    return
                }
                completion(document, nil)
            }
        }
    }

    static func get(id: String, cachePolicy: CachePolicy = .default, completion: @escaping ((Self?, Error?) -> Void)) {
        let documentReference: DocumentReference = Self.init(id: id).documentReference
        self.get(documentReference: documentReference, cachePolicy: cachePolicy, completion: completion)
    }

    static func get(documentReference: DocumentReference) -> Self? {
        return Store.shared.get(documentType: self, reference: documentReference)
    }

    static func listen(id: String, includeMetadataChanges: Bool = true, completion: @escaping ((Self?, Error?) -> Void)) -> Disposer {
        let listenr: ListenerRegistration = Self.collectionReference.document(id).addSnapshotListener(includeMetadataChanges: includeMetadataChanges) { (snapshot, error) in
            if let error = error {
                completion(nil, error)
                return
            }
            guard let document: Self = Self(snapshot: snapshot!) else {
                completion(nil, DocumentError.invalidData)
                return
            }
            completion(document, nil)
        }
        return Disposer(.value(listenr))
    }
}
